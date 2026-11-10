package ch.qwt.obstgarten;

import de.maxhenkel.voicechat.api.BukkitVoicechatService;
import de.maxhenkel.voicechat.api.VoicechatConnection;
import de.maxhenkel.voicechat.api.VoicechatPlugin;
import de.maxhenkel.voicechat.api.VoicechatServerApi;
import de.maxhenkel.voicechat.api.events.EventRegistration;
import de.maxhenkel.voicechat.api.events.VoicechatServerStartedEvent;
import com.github.retrooper.packetevents.PacketEvents;
import com.github.retrooper.packetevents.event.PacketListener;
import com.github.retrooper.packetevents.event.PacketListenerPriority;
import com.github.retrooper.packetevents.event.PacketSendEvent;
import com.github.retrooper.packetevents.protocol.packettype.PacketType;
import com.github.retrooper.packetevents.protocol.player.UserProfile;
import com.github.retrooper.packetevents.wrapper.play.server.WrapperPlayServerPlayerInfoUpdate;
import com.github.retrooper.packetevents.wrapper.play.server.WrapperPlayServerSystemChatMessage;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.TextReplacementConfig;
import me.clip.placeholderapi.expansion.PlaceholderExpansion;
import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.plugin.java.JavaPlugin;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.regex.Pattern;

/**
 * Sidebar for TAB, as PlaceholderAPI placeholders:
 * <ul>
 * <li>%obstgarten_title% and %obstgarten_goal%: the nether goal, "Nether
 * öffnet, wenn / alle [chestplate] haben", or "Nether ist offen!" once
 * the nether is open (gamerule; the goal line is then empty).</li>
 * <li>%obstgarten_line_0% ... %obstgarten_line_N%: one line per member
 * (whitelist + ops), online first, e.g. "Mia [heart]7 [diamond]5/8 [speaker]". Offline
 * members are grey, without hearts. Empty when there is no such member
 * (TAB then hides the line).</li>
 * </ul>
 * Names are the Essentials nicknames (else the account name, without
 * Floodgate's "."). Health in hearts, coloured by how much is left; the speaker
 * when the player is connected to voice chat (mod or web page).
 * <p>
 * Progress: diamonds (a block counts 9) in the inventory and ender chest, up
 * to {@link #GOAL}; a diamond or netherite chestplate anywhere there means
 * done, for good. Only online players can be looked at, so the last state is
 * kept in plugins/ObstgartenSidebar/progress.yml.
 * <p>
 * Name tags (and the tab list) show the nickname too: when the server
 * announces a player to the others (player info packet, through
 * PacketEvents), the name in it is swapped for the nickname. Java clients
 * and Geyser both take the name tag from there. Only what the clients see
 * changes; on the server, commands still use the account name. A player's
 * own entry is left alone, and a changed nickname is sent out again right
 * away (hide + show). Messages the server writes itself (advancements,
 * deaths, joins) get the nickname the same way.
 */
public final class ObstgartenSidebar extends JavaPlugin implements Listener {

    // formatting (§ codes; TAB passes them on)
    static final String NAME = "§f";
    static final String OFFLINE = "§7";
    static final String HEART = "§f\uE102"; // icon; white = its own red
    static final String HEARTS_OK = "§f";      // 7-10 hearts
    static final String HEARTS_LOW = "§e";     // 4-6
    static final String HEARTS_CRIT = "§c";    // 0-3
    static final String VOICE = " §a\uE103"; // white speaker icon, tinted green
    static final String TITLE_GOAL = "§6Nether öffnet, wenn";
    static final String TITLE_OPEN = "§aNether ist offen!";

    // icons: font characters from the server packs (sidebar-icons), also
    // HEART and VOICE above
    static final String DIAMOND = "\uE100";
    static final String CHESTPLATE = "\uE101";
    static final String GOAL_LINE = "§6alle §f" + CHESTPLATE + "§6 haben";

    /** Diamonds for a chestplate. */
    static final int GOAL = 8;

    private static final Pattern COLOUR_CODES = Pattern.compile("(?i)[&§](#[0-9a-f]{6}|[0-9a-fk-orx])");

    record Progress(int diamonds, boolean done) {
    }

    record Member(UUID id, String name, boolean online) {
    }

    private volatile VoicechatServerApi voice;
    private final Map<UUID, Progress> progress = new ConcurrentHashMap<>();
    private final Map<UUID, String> names = new ConcurrentHashMap<>();
    private volatile List<Member> members = List.of();
    // account name (Floodgate's with ".") -> nickname, and a pattern that
    // finds exactly these names (".eeeeeeeevelyn" and "eeeeeeeevelyn" are
    // different players); null when nobody has a nickname
    private volatile Map<String, String> accountNicks = Map.of();
    private volatile Pattern accountPattern;
    private volatile boolean netherOpen;
    private boolean nametags;
    private boolean namesLoaded;
    private File progressFile;
    private boolean dirty;
    private int ticks;

    @Override
    public void onEnable() {
        if (Bukkit.getPluginManager().isPluginEnabled("voicechat")) {
            BukkitVoicechatService service = Bukkit.getServicesManager().load(BukkitVoicechatService.class);
            if (service != null) {
                service.registerPlugin(new VoicechatPlugin() {
                    @Override
                    public String getPluginId() {
                        return "obstgarten_sidebar";
                    }

                    @Override
                    public void registerEvents(EventRegistration registration) {
                        registration.registerEvent(VoicechatServerStartedEvent.class,
                                event -> voice = event.getVoicechat());
                    }
                });
            }
        }

        progressFile = new File(getDataFolder(), "progress.yml");
        loadProgress();
        netherOpen = netherOpen();
        Bukkit.getPluginManager().registerEvents(this, this);
        // inventories and the member list are read on the main thread,
        // TAB asks for the placeholders from its own thread
        Bukkit.getScheduler().runTaskTimer(this, this::update, 1L, 20L);
        new Lines(this).register();

        // all PacketEvents classes stay in Nametags, so the rest works without it
        if (Bukkit.getPluginManager().isPluginEnabled("packetevents")) {
            Nametags.register(this);
            nametags = true;
        } else {
            getLogger().warning("packetevents is missing, name tags keep the account names");
        }
    }

    /** The nickname for name tags, at most 16 characters (Java's limit); null: keep the name. */
    String nametag(UUID id) {
        String nick = names.get(id);
        return nick == null ? null : nick.length() > 16 ? nick.substring(0, 16) : nick;
    }

    @Override
    public void onDisable() {
        for (Player player : Bukkit.getOnlinePlayers()) {
            measure(player);
        }
        saveProgress();
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent event) {
        measure(event.getPlayer());
        saveProgress();
    }

    /** Every second: progress of online players, member list; names every 10s. */
    private void update() {
        netherOpen = netherOpen();
        for (Player player : Bukkit.getOnlinePlayers()) {
            measure(player);
        }
        if (ticks++ % 10 == 0) {
            refreshNames();
        }

        Map<UUID, OfflinePlayer> all = new LinkedHashMap<>();
        for (OfflinePlayer player : Bukkit.getWhitelistedPlayers()) {
            all.put(player.getUniqueId(), player);
        }
        for (OfflinePlayer player : Bukkit.getOperators()) {
            all.put(player.getUniqueId(), player);
        }
        for (Player player : Bukkit.getOnlinePlayers()) {
            all.put(player.getUniqueId(), player);
        }
        List<Member> list = new ArrayList<>();
        for (OfflinePlayer player : all.values()) {
            list.add(new Member(player.getUniqueId(), name(player), player.isOnline()));
        }
        list.sort(Comparator.comparing((Member m) -> !m.online())
                .thenComparing(m -> m.name().toLowerCase(Locale.ROOT)));
        members = List.copyOf(list);

        Map<String, String> nicks = new java.util.HashMap<>();
        for (OfflinePlayer player : all.values()) {
            String account = player.getName();
            String nick = names.get(player.getUniqueId());
            if (account != null && nick != null && !account.equals(nick)) {
                nicks.put(account, nick);
            }
        }
        if (!nicks.equals(accountNicks)) {
            // longest first; not next to letters, digits, "_" or "." (before)
            String alternatives = nicks.keySet().stream()
                    .sorted(Comparator.comparingInt(String::length).reversed())
                    .map(Pattern::quote)
                    .collect(java.util.stream.Collectors.joining("|"));
            accountPattern = nicks.isEmpty() ? null
                    : Pattern.compile("(?<![\\w.])(?:" + alternatives + ")(?!\\w)");
            accountNicks = Map.copyOf(nicks);
        }

        if (dirty) {
            saveProgress();
        }
    }

    /**
     * On this version the gamerule decides (allow-nether in server.properties is
     * ignored), and it takes effect right away: /gamerule
     * allow_entering_nether_using_portals true opens the nether.
     */
    private static boolean netherOpen() {
        String rule = Bukkit.getWorlds().get(0).getGameRuleValue("allow_entering_nether_using_portals");
        return rule != null ? Boolean.parseBoolean(rule) : Bukkit.getAllowNether();
    }

    private void measure(Player player) {
        Progress old = progress.get(player.getUniqueId());
        int diamonds = 0;
        boolean done = old != null && old.done();
        for (ItemStack[] items : List.of(player.getInventory().getContents(),
                player.getEnderChest().getContents())) {
            for (ItemStack item : items) {
                if (item == null) {
                    continue;
                }
                switch (item.getType()) {
                    case DIAMOND -> diamonds += item.getAmount();
                    case DIAMOND_BLOCK -> diamonds += 9 * item.getAmount();
                    case DIAMOND_CHESTPLATE, NETHERITE_CHESTPLATE -> done = true;
                    default -> {
                    }
                }
            }
        }
        Progress now = new Progress(Math.min(diamonds, GOAL), done);
        if (!now.equals(old)) {
            progress.put(player.getUniqueId(), now);
            dirty = true;
        }
    }

    private void refreshNames() {
        File userdata = new File(getDataFolder().getParentFile(), "Essentials/userdata");
        Map<UUID, String> found = new ConcurrentHashMap<>();
        File[] files = userdata.listFiles((dir, file) -> file.endsWith(".yml"));
        if (files != null) {
            for (File file : files) {
                try {
                    UUID id = UUID.fromString(file.getName().substring(0, file.getName().length() - 4));
                    String nick = YamlConfiguration.loadConfiguration(file).getString("nickname");
                    if (nick != null) {
                        nick = COLOUR_CODES.matcher(nick).replaceAll("").trim();
                        if (!nick.isEmpty()) {
                            found.put(id, nick);
                        }
                    }
                } catch (IllegalArgumentException e) {
                    // not a player file
                }
            }
        }
        List<Player> renamed = new ArrayList<>();
        for (Player player : Bukkit.getOnlinePlayers()) {
            if (!java.util.Objects.equals(names.get(player.getUniqueId()), found.get(player.getUniqueId()))) {
                renamed.add(player);
            }
        }
        names.keySet().retainAll(found.keySet());
        names.putAll(found);

        // announce renamed players again, so the others get the new name tag
        // (not on the first read: then nobody has seen a name yet)
        if (nametags && namesLoaded) {
            for (Player target : renamed) {
                for (Player viewer : Bukkit.getOnlinePlayers()) {
                    if (viewer != target && viewer.canSee(target)) {
                        viewer.hidePlayer(this, target);
                        viewer.showPlayer(this, target);
                    }
                }
            }
        }
        namesLoaded = true;
    }

    private String name(OfflinePlayer player) {
        String nick = names.get(player.getUniqueId());
        if (nick != null) {
            return nick;
        }
        String name = player.getName();
        if (name == null) {
            return player.getUniqueId().toString().substring(0, 8);
        }
        return name.startsWith(".") ? name.substring(1) : name;
    }

    private void loadProgress() {
        YamlConfiguration yaml = YamlConfiguration.loadConfiguration(progressFile);
        for (String key : yaml.getKeys(false)) {
            try {
                progress.put(UUID.fromString(key), new Progress(
                        yaml.getInt(key + ".diamonds"), yaml.getBoolean(key + ".done")));
            } catch (IllegalArgumentException e) {
                getLogger().warning("progress.yml: skipping " + key);
            }
        }
    }

    private void saveProgress() {
        YamlConfiguration yaml = new YamlConfiguration();
        progress.forEach((id, p) -> {
            yaml.set(id + ".diamonds", p.diamonds());
            yaml.set(id + ".done", p.done());
        });
        try {
            yaml.save(progressFile);
            dirty = false;
        } catch (IOException e) {
            getLogger().log(Level.WARNING, "could not save " + progressFile, e);
        }
    }

    /**
     * The line with spaces in front, so it sits in the middle under the
     * title (sidebar lines are left-aligned): half of what the widest line
     * or the title has more. Off by at most a space (4px).
     */
    String centred(String text) {
        int widest = width(netherOpen ? TITLE_OPEN : TITLE_GOAL);
        for (Member member : members) {
            widest = Math.max(widest, width(line(member)));
        }
        int spaces = Math.max(0, Math.round((widest - width(text)) / 2f / 4f));
        return " ".repeat(spaces) + text;
    }

    /**
     * Width in pixels in the Minecraft font (same widths on Java and Bedrock):
     * glyph plus 1px gap, bold 1px more, § codes take no space.
     */
    static int width(String text) {
        int width = 0;
        boolean bold = false;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == '§' && i + 1 < text.length()) {
                char code = Character.toLowerCase(text.charAt(++i));
                if (code == 'l') {
                    bold = true;
                } else if (code == 'r' || (code >= '0' && code <= '9') || (code >= 'a' && code <= 'f')) {
                    bold = false; // a colour resets the formatting
                }
                continue;
            }
            width += switch (c) {
                case 'i', '!', '.', ',', ':', ';', '|', '\'' -> 2;
                case 'l', '`' -> 3;
                case 't', 'I', '[', ']', ' ', '"', '(', ')' -> 4;
                case 'f', 'k', '<', '>', '{', '}', '*' -> 5;
                case '\uE100', '\uE101', '\uE102', '\uE103' -> 10; // icons, about 9px wide
                default -> 6;
            };
            if (bold && c != ' ') {
                width++;
            }
        }
        return width;
    }

    String line(Member member) {
        Progress p = progress.getOrDefault(member.id(), new Progress(0, false));
        // the colour also tints the icon: white = the texture as is
        String colour = member.online() ? NAME : OFFLINE;
        StringBuilder line = new StringBuilder().append(colour).append(member.name());

        Player player = member.online() ? Bukkit.getPlayer(member.id()) : null;
        if (player != null) {
            int hearts = (int) Math.ceil(Math.max(0, player.getHealth()) / 2.0);
            String heartsColour = hearts >= 7 ? HEARTS_OK : hearts >= 4 ? HEARTS_LOW : HEARTS_CRIT;
            line.append(' ').append(HEART).append(heartsColour).append(hearts);
        }
        if (!netherOpen) {
            line.append(' ').append(colour);
            if (p.done()) {
                line.append(CHESTPLATE);
            } else {
                line.append(DIAMOND).append(p.diamonds()).append('/').append(GOAL);
            }
        }
        if (player != null && inVoice(player)) {
            line.append(VOICE);
        }
        return line.toString();
    }

    boolean inVoice(Player player) {
        VoicechatServerApi api = voice;
        if (api == null) {
            return false;
        }
        try {
            VoicechatConnection connection = api.getConnectionOf(player.getUniqueId());
            return connection != null && connection.isConnected() && !connection.isDisabled();
        } catch (RuntimeException e) {
            return false;
        }
    }

    /** The PlaceholderAPI expansion "obstgarten". */
    static final class Lines extends PlaceholderExpansion {

        private final ObstgartenSidebar plugin;

        Lines(ObstgartenSidebar plugin) {
            this.plugin = plugin;
        }

        @Override
        public String getIdentifier() {
            return "obstgarten";
        }

        @Override
        public String getAuthor() {
            return "obstgarten";
        }

        @Override
        public String getVersion() {
            return plugin.getDescription().getVersion();
        }

        @Override
        public boolean persist() {
            return true;
        }

        @Override
        public String onRequest(OfflinePlayer viewer, String params) {
            if (params.equals("title")) {
                return plugin.netherOpen ? TITLE_OPEN : TITLE_GOAL;
            }
            if (params.equals("goal")) {
                return plugin.netherOpen ? "" : plugin.centred(GOAL_LINE);
            }
            if (!params.startsWith("line_")) {
                return null;
            }
            int index;
            try {
                index = Integer.parseInt(params.substring("line_".length()));
            } catch (NumberFormatException e) {
                return null;
            }
            List<Member> list = plugin.members;
            return index >= 0 && index < list.size() ? plugin.line(list.get(index)) : "";
        }
    }

    /**
     * Swaps the account name for the nickname in the player info the others
     * get (see the class comment). Its own class, so PacketEvents is only
     * loaded when it is there.
     */
    static final class Nametags {

        static void register(ObstgartenSidebar plugin) {
            PacketEvents.getAPI().getEventManager().registerListener(new PacketListener() {
                @Override
                public void onPacketSend(PacketSendEvent event) {
                    if (event.getPacketType() == PacketType.Play.Server.SYSTEM_CHAT_MESSAGE) {
                        systemMessage(plugin, event);
                        return;
                    }
                    if (event.getPacketType() != PacketType.Play.Server.PLAYER_INFO_UPDATE) {
                        return;
                    }
                    WrapperPlayServerPlayerInfoUpdate packet = new WrapperPlayServerPlayerInfoUpdate(event);
                    if (!packet.getActions().contains(WrapperPlayServerPlayerInfoUpdate.Action.ADD_PLAYER)) {
                        return;
                    }
                    UUID receiver = event.getUser().getUUID();
                    boolean changed = false;
                    for (WrapperPlayServerPlayerInfoUpdate.PlayerInfo info : packet.getEntries()) {
                        UserProfile profile = info.getGameProfile();
                        if (profile == null || profile.getUUID() == null || profile.getUUID().equals(receiver)) {
                            continue;
                        }
                        String nick = plugin.nametag(profile.getUUID());
                        if (nick != null && !nick.equals(profile.getName())) {
                            profile.setName(nick);
                            changed = true;
                        }
                    }
                    if (changed) {
                        event.markForReEncode(true);
                    }
                }
            }, PacketListenerPriority.NORMAL);
        }

        /**
         * Messages the server writes itself (advancements, deaths, joins,
         * command answers) name players by account: the nickname instead,
         * wherever an account name stands on its own.
         */
        private static void systemMessage(ObstgartenSidebar plugin, PacketSendEvent event) {
            Pattern accounts = plugin.accountPattern;
            Map<String, String> nicks = plugin.accountNicks;
            if (accounts == null) {
                return;
            }
            WrapperPlayServerSystemChatMessage packet = new WrapperPlayServerSystemChatMessage(event);
            Component message = packet.getMessage();
            if (message == null) {
                return;
            }
            Component renamed = message.replaceText(TextReplacementConfig.builder()
                    .match(accounts)
                    .replacement((match, text) -> text.content(nicks.getOrDefault(match.group(), match.group())))
                    .build());
            if (!renamed.equals(message)) {
                packet.setMessage(renamed);
                event.markForReEncode(true);
            }
        }
    }
}

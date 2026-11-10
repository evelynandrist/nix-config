package ch.qwt.obstgarten.themes;

import org.geysermc.event.subscribe.Subscribe;
import org.geysermc.geyser.api.command.Command;
import org.geysermc.geyser.api.connection.GeyserConnection;
import org.geysermc.geyser.api.event.bedrock.SessionLoadResourcePacksEvent;
import org.geysermc.geyser.api.event.lifecycle.GeyserDefineCommandsEvent;
import org.geysermc.geyser.api.extension.Extension;
import org.geysermc.geyser.api.pack.PackCodec;
import org.geysermc.geyser.api.pack.ResourcePack;
import org.geysermc.geyser.api.pack.option.ResourcePackOption;
import org.geysermc.geyser.api.util.TriState;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.TreeMap;

/**
 * Optional UI themes for Bedrock players: every themes/NAME.mcpack in the
 * extension folder is a theme. Players pick one with /theme NAME (or
 * /theme normal); the choice is stored by Xbox ID in choices.properties and
 * the pack is sent on their next join. Nobody gets a theme by default.
 */
public final class ObstgartenThemes implements Extension {

    private static final String NORMAL = "normal";

    /** theme name -> pack */
    private Map<String, ResourcePack> themes;
    private final Properties choices = new Properties();

    @Override
    public String rootCommand() {
        return "theme";
    }

    private synchronized Map<String, ResourcePack> themes() {
        if (themes != null) {
            return themes;
        }
        themes = new TreeMap<>();
        Path dir = dataFolder().resolve("themes");
        try {
            Files.createDirectories(dir);
            try (DirectoryStream<Path> files = Files.newDirectoryStream(dir, "*.mcpack")) {
                for (Path file : files) {
                    String name = file.getFileName().toString().replaceFirst("\\.mcpack$", "")
                            .toLowerCase(Locale.ROOT);
                    if (name.equals(NORMAL)) {
                        continue;
                    }
                    try {
                        themes.put(name, ResourcePack.create(PackCodec.path(file)));
                    } catch (Exception e) {
                        logger().error("Could not load theme " + file, e);
                    }
                }
            }
        } catch (IOException e) {
            logger().error("Could not read " + dir, e);
        }

        Path choicesFile = dataFolder().resolve("choices.properties");
        if (Files.exists(choicesFile)) {
            try (Reader reader = Files.newBufferedReader(choicesFile, StandardCharsets.UTF_8)) {
                choices.load(reader);
            } catch (IOException e) {
                logger().error("Could not read " + choicesFile, e);
            }
        }

        logger().info("Themes: " + themes.keySet() + ", " + choices.size() + " player choice(s)");
        return themes;
    }

    private synchronized void choose(String xuid, String theme) {
        if (theme.equals(NORMAL)) {
            choices.remove(xuid);
        } else {
            choices.setProperty(xuid, theme);
        }
        Path file = dataFolder().resolve("choices.properties");
        Path tmp = dataFolder().resolve("choices.properties.tmp");
        try {
            try (Writer writer = Files.newBufferedWriter(tmp, StandardCharsets.UTF_8)) {
                choices.store(writer, "Xbox ID = theme (set with /theme)");
            }
            Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            logger().error("Could not save " + file, e);
        }
    }

    private synchronized String chosen(String xuid) {
        return xuid == null ? null : choices.getProperty(xuid);
    }

    @Subscribe
    public void onLoadPacks(SessionLoadResourcePacksEvent event) {
        String theme = chosen(event.connection().xuid());
        ResourcePack pack = theme == null ? null : themes().get(theme);
        if (pack != null) {
            // the overload with options; register(pack) goes away in Geyser 2.13
            event.register(pack, new ResourcePackOption<?>[0]);
        }
    }

    @Subscribe
    public void onDefineCommands(GeyserDefineCommandsEvent event) {
        for (String theme : themes().keySet()) {
            event.register(command(theme, "Use the " + theme + " look (after rejoining)"));
        }
        event.register(command(NORMAL, "Back to the normal look (after rejoining)"));
        event.register(Command.<GeyserConnection>builder(this)
                .source(GeyserConnection.class)
                .name("list")
                .description("Show the available looks")
                .permission("obstgarten.theme", TriState.TRUE)
                .playerOnly(true)
                .bedrockOnly(true)
                .executor((player, command, args) -> {
                    String current = chosen(player.xuid());
                    player.sendMessage("§6Looks: §f" + NORMAL + ", " + String.join(", ", themes().keySet()));
                    player.sendMessage("§6Yours: §f" + (current == null ? NORMAL : current)
                            + "§7  (change: /theme <name>)");
                })
                .build());
    }

    private Command command(String theme, String description) {
        return Command.<GeyserConnection>builder(this)
                .source(GeyserConnection.class)
                .name(theme)
                .description(description)
                .permission("obstgarten.theme", TriState.TRUE)
                .playerOnly(true)
                .bedrockOnly(true)
                .executor((player, command, args) -> {
                    String before = chosen(player.xuid());
                    String now = theme.equals(NORMAL) ? null : theme;
                    if (java.util.Objects.equals(before, now)) {
                        player.sendMessage("§7You already have the " + theme + " look.");
                        return;
                    }
                    choose(player.xuid(), theme);
                    player.sendMessage("§aLook set to " + theme + ". §fLeave and join again to see it.");
                })
                .build();
    }
}

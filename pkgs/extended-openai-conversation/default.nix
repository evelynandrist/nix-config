{ lib
, buildHomeAssistantComponent
, fetchFromGitHub

# dependencies
, openai
}:

buildHomeAssistantComponent rec {
  owner = "jekalmin";
  domain = "extended_openai_conversation";
  version = "1.0.4-beta2";

  src = fetchFromGitHub {
    inherit owner;
    repo = "extended_openai_conversation";
    rev = "refs/tags/${version}";
    hash = "sha256-f8KWTP/BK31GpEPVCCYohJVjEZX5al4gri/gaE9g69I=";
  };

  dependencies = [
    openai
  ];

  postPatch = ''
    substituteInPlace custom_components/${domain}/manifest.json --replace-fail 'openai~=1.3.8' 'openai>=1.3.8'
  '';

  meta = with lib; {
    description = "Home Assistant custom component of conversation agent. It uses OpenAI to control your devices.";
    homepage = "https://github.com/jekalmin/extended_openai_conversation";
    changelog = "https://github.com/jekalmin/extended_openai_conversation/releases/tag/${version}";
    # license = licenses.mit;
    # maintainers = with maintainers; [ pathob ];
  };
}

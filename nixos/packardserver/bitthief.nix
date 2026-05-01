{ config, lib, pkgs, ... }: 
{
  config.virtualisation.oci-containers.containers.bitthief = 
    let
      bitthiefImage = pkgs.dockerTools.buildImage {
	name = "bitthief";
	tag = "latest";
	
	copyToRoot = [
	  (pkgs.buildEnv {
	    name = "image-root";
	    pathsToLink = [ "/bin" ];
	    paths = [
	      pkgs.bash
	      pkgs.busybox
	      pkgs.jre8
	      pkgs.strace
	    ];
	  })
	  ./bitthief
	  # the file needs to be in a folder, otherwise copyToRoot complains
	  (pkgs.runCommand "bitthief-jar" { } ''
	    mkdir -p $out
	    cp ${builtins.fetchurl {
	      url = "https://web.archive.org/web/20200219234211if_/https://www.bitthief.ethz.ch/dist/BitThief.jar";
	      sha256 = "1wblwwld3scv31slq85jmc33hf53ny9ygl72rq1s0rlfkg5awmwk";
	    }} $out/BitThief.jar
	  '')
	];

	config = {
	  Entrypoint = [ "/bin/java" "-Xms192m" "-Xmx512m" "-Duser.home=/" "-jar" "BitThief.jar" "-nogui" ];
	};
      };
    in {
    image = "bitthief:latest";
    imageFile = "${bitthiefImage}";
    # environmentFiles = [ config.sops.templates."umami.env".path ];
    ports = [ "127.0.0.1:3393:8080" ];
  };
}

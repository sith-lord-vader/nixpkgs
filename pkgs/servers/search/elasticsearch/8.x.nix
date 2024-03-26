{ elk8Version
, lib
, stdenv
, fetchurl
, makeWrapper
, jre_headless
, util-linux
, gnugrep
, coreutils
, autoPatchelfHook
, zlib
}:

with lib;
let
  info = splitString "-" stdenv.hostPlatform.system;
  arch = elemAt info 0;
  plat = elemAt info 1;
  hashes =
    {
      x86_64-linux = "sha256-SgNVlwcrLmQ5y9wUSmIrsaXCIzcdByvq+/XY6+6BY0Q=";
      x86_64-darwin = "sha256-Z8FeR8rvI9aq3FsRXSp4oZonHDNH3aPYwJsYPZivy5s=";
      aarch64-linux = "sha256-s2TUPTOE5rbHQBCkL4BLYmE4/PRCo4ipr7RsParfxSs=";
      aarch64-darwin = "sha256-y8YgrW1GpLSACCoz56BY/PH6+4n+avhvheCM+FnxWVk=";
    };
in
stdenv.mkDerivation rec {
  pname = "elasticsearch";
  version = elk8Version;

  src = fetchurl {
    url = "https://artifacts.elastic.co/downloads/elasticsearch/${pname}-${version}-${plat}-${arch}.tar.gz";
    hash = hashes.${stdenv.hostPlatform.system} or (throw "Unknown architecture");
  };

  patches = [ ./es-home-6.x.patch ];

  postPatch = ''
    		substituteInPlace bin/elasticsearch-env --replace \
    			"ES_CLASSPATH=\"\$ES_HOME/lib/*\"" \
    			"ES_CLASSPATH=\"$out/lib/*\""
    		substituteInPlace bin/elasticsearch-cli --replace \
    			"LAUNCHER_CLASSPATH=\$ES_HOME\/lib\/\*:\$ES_HOME\/lib\/cli-launcher\/\*" \
          "LAUNCHER_CLASSPATH=\$out\/lib\/\*:\$out\/lib\/cli-launcher\/\*"
    	'';

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optional (!stdenv.hostPlatform.isDarwin) autoPatchelfHook;

  buildInputs = [ jre_headless util-linux zlib ];

  runtimeDependencies = [ zlib ];

  installPhase = ''
    		mkdir -p $out
    		cp -R bin config lib modules plugins $out
    		chmod +x $out/bin/*
    		substituteInPlace $out/bin/elasticsearch \
    			--replace 'bin/elasticsearch-keystore' "$out/bin/elasticsearch-keystore"
        wrapProgram $out/bin/elasticsearch-env \
    			--set ES_JAVA_HOME "${jre_headless}" \
          --set ES_HOME "$out" \
          --set ES_CLASSPATH "$out/lib/*"
    		wrapProgram $out/bin/elasticsearch \
    			--prefix PATH : "${makeBinPath [ util-linux coreutils gnugrep ]}" \
    			--set ES_JAVA_HOME "${jre_headless}"
    		wrapProgram $out/bin/elasticsearch-plugin --set ES_JAVA_HOME "${jre_headless}"
    	'';

  passthru = { enableUnfree = true; };

  meta = {
    description = "Open Source, Distributed, RESTful Search Engine";
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    license = licenses.elastic20;
    platforms = platforms.unix;
    maintainers = with maintainers; [ apeschar basvandijk sith-lord-vader ];
  };
}

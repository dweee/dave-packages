{
  lib,
  fetchurl,
  fetchPypi,
}: final: _prev: {
  # Nixpkgs' source MLX disables Metal; its binary package is still 0.32.0.
  # Match the separator's 0.32.3 requirement with upstream's paired wheels.
  mlx-metal = final.buildPythonPackage {
    pname = "mlx-metal";
    version = "0.32.3";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/f8/ed/8510985bcb24a6eae359a5441ce4cedcee13b84258a010cd0e515e9fb0bc/mlx_metal-0.32.3-py3-none-macosx_14_0_arm64.whl";
      hash = "sha256-/bqI7ZExRIzxY74setY3R0bYgYIF8oZXqpG2xpBQ9pE=";
    };
    dontStrip = true;
    meta = {
      license = with lib.licenses; [mit asl20];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
    };
  };
  mlx = final.buildPythonPackage {
    pname = "mlx";
    version = "0.32.3";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/74/91/4d7dc37533d5439e27e57b09d2200b1a7988e433259d9beac8f8241197e4/mlx-0.32.3-cp314-cp314-macosx_14_0_arm64.whl";
      hash = "sha256-LcEIX1wuuhjNrAldf7C2jd+t1Rv2lbGKEQLtoV53520=";
    };
    dependencies = [final.mlx-metal];
    dontStrip = true;
    postInstall = ''
      for dir in lib include share; do
        ln -s ${final.mlx-metal}/${final.python.sitePackages}/mlx/$dir \
          "$out/${final.python.sitePackages}/mlx/$dir"
      done
    '';
    pythonImportsCheck = ["mlx.core"];
    meta = {
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
    };
  };
  mlx-audio-io = final.buildPythonPackage {
    pname = "mlx-audio-io";
    version = "1.3.24";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/4e/2c/b4e62457dcc6bdcc1f88bca136593a35c7b7b69952baeb0d51e137c0566a/mlx_audio_io-1.3.24-cp314-cp314-macosx_14_0_arm64.whl";
      hash = "sha256-4OAcgJ7DyFd8ssEJ7ztdXcBnBz28Vwtz1KKJKRCXFVU=";
    };
    dependencies = [final.mlx];
    dontStrip = true;
    pythonImportsCheck = ["mlx_audio_io"];
    meta = {
      license = with lib.licenses; [mit lgpl21Plus];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
    };
  };
  mlx-spectro = final.buildPythonPackage {
    pname = "mlx-spectro";
    version = "0.9.10";
    pyproject = true;
    src = fetchPypi {
      pname = "mlx_spectro";
      version = "0.9.10";
      hash = "sha256-Gb2s+rcy1u788G/IeEmmoEJbMhM831Kh1/Wi3fcTqOc=";
    };
    build-system = [final.hatchling];
    dependencies = [final.mlx final.numpy];
    pythonImportsCheck = ["mlx_spectro"];
    meta = {
      license = lib.licenses.mit;
      platforms = ["aarch64-darwin"];
    };
  };
}

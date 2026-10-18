{ lib, ... }: {
  # Linux 6.1.188 adds the indirect-descriptor clear immediately before the
  # line removed by the pinned AVF balloon patch. Restore that kernel change
  # after AVF applies, so the final source keeps both intended behaviors.
  boot.kernelPatches = lib.mkMerge [
    (lib.mkBefore [
      {
        name = "avf-balloon-6.1.188-context-before";
        patch = ./patches/avf-balloon-6.1.188-context-before.patch;
      }
    ])
    (lib.mkAfter [
      {
        name = "avf-balloon-6.1.188-context-after";
        patch = ./patches/avf-balloon-6.1.188-context-after.patch;
      }
    ])
  ];

}

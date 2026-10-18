// Confirm that headless Ghidra actually decompiles through the Kuna backend.
// @category Tests

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;

public class KunaSmoke extends GhidraScript {
    private Function findFixtureFunction(String name) {
        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
        while (functions.hasNext()) {
            Function function = functions.next();
            // Mach-O toolchains may retain a leading underscore.
            if (function.getName().equals(name) || function.getName().equals("_" + name)) {
                return function;
            }
        }
        throw new AssertionError("The imported fixture has no function named " + name);
    }

    private String decompile(DecompInterface decompiler, String name) {
        DecompileResults result = decompiler.decompileFunction(findFixtureFunction(name), 30, monitor);
        if (!result.decompileCompleted() || result.getDecompiledFunction() == null) {
            throw new AssertionError("Failed to decompile " + name + ": " + result.getErrorMessage());
        }
        String code = result.getDecompiledFunction().getC();
        if (!code.contains("Kuna v")) {
            throw new AssertionError("The selected native core did not identify itself as Kuna:\n" + code);
        }
        if (!code.contains("return")) {
            throw new AssertionError("The decompiler returned no computed function body:\n" + code);
        }
        return code;
    }

    @Override
    public void run() throws Exception {
        if (currentProgram == null) {
            throw new AssertionError("Import the compiled fixture before running this script");
        }
        DecompInterface decompiler = new DecompInterface();
        try {
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            if (!decompiler.openProgram(currentProgram)) {
                throw new AssertionError("Cannot initialize the selected native decompiler: " + decompiler.getLastMessage());
            }
            String probe = decompile(decompiler, "kuna_probe");
            String constant = decompile(decompiler, "kuna_constant");
            String expected = "(?:0x4b554e41|" + Long.toString(0x4b554e41L) + ")[uUlL]*";
            if (!Pattern.compile("(?is)\\breturn\\b[^;]*\\b" + expected + "\\b").matcher(constant).find()) {
                throw new AssertionError("The decompiled return value differs from the fixture constant:\n" + constant);
            }
            String report = probe + "\n" + constant;
            String[] args = getScriptArgs();
            if (args.length > 0) {
                Files.writeString(Path.of(args[0]), report, StandardCharsets.UTF_8);
            }
            println(report);
            println("KUNA_HEADLESS_SMOKE_PASSED");
        } finally {
            decompiler.dispose();
        }
    }
}

// Exercise Ghidra 12.2 API compatibility against an isolated imported fixture.
// @category Tests
import com.xebyte.core.DataTypeService;
import com.xebyte.core.ProgramProvider;
import com.xebyte.core.Response;
import com.xebyte.core.ServiceUtils;
import com.xebyte.headless.DirectThreadingStrategy;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.ByteDataType;
import ghidra.program.model.data.DataTypeConflictHandler;
import ghidra.program.model.data.StructureDataType;
import ghidra.program.model.listing.Program;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;

public class FlakeyCompatibilitySmoke extends GhidraScript {
    @Override public void run() throws Exception {
        if (currentProgram == null) throw new AssertionError("No isolated fixture program");
        ProgramProvider provider = new ProgramProvider() {
            public Program getCurrentProgram() { return currentProgram; }
            public Program getProgram(String name) {
                return currentProgram.getName().equals(name) ? currentProgram : null;
            }
            public Program[] getAllOpenPrograms() { return new Program[] {currentProgram}; }
            public void setCurrentProgram(Program program) { throw new UnsupportedOperationException(); }
        };
        var manager = currentProgram.getDataTypeManager();
        int transaction = currentProgram.startTransaction("Create compatibility-only scratch type");
        try {
            var structure = new StructureDataType("FlakeyCompatibilityDeleteProbe", 0);
            structure.add(ByteDataType.dataType, "field", "test fixture");
            manager.addDataType(structure, DataTypeConflictHandler.DEFAULT_HANDLER);
        } finally { currentProgram.endTransaction(transaction, true); }
        var service = new DataTypeService(provider, new DirectThreadingStrategy());
        Response deleted = service.deleteDataType("FlakeyCompatibilityDeleteProbe", false, currentProgram);
        if (!(deleted instanceof Response.Ok) || manager.getDataType("/FlakeyCompatibilityDeleteProbe") != null)
            throw new AssertionError("Deletion did not remove the scratch type: " + deleted.toJson());
        if (!(service.deleteDataType("FlakeyCompatibilityDeleteProbe", false, currentProgram) instanceof Response.Err))
            throw new AssertionError("Missing type deletion must remain an error");
        var choices = ServiceUtils.languageVariantChoices(currentProgram);
        if (choices.isEmpty() || ServiceUtils.variantEnumerationFailed(currentProgram))
            throw new AssertionError("Real language enumeration failed");
        var decoders = new HashSet<String>();
        for (var choice : choices) {
            if (!(choice.decoder().endsWith(".sla") || choice.decoder().endsWith(".slaspec")))
                throw new AssertionError("Decoder fell back to a language ID: " + choice.decoder());
            decoders.add(choice.decoder());
        }
        if (decoders.size() != 1 || ServiceUtils.variantAmbiguous(currentProgram))
            throw new AssertionError("The x86 fixture unexpectedly has multiple decoder identities");
        Files.writeString(Path.of(getScriptArgs()[0]), "GHIDRA_MCP_COMPATIBILITY_PASSED\n");
        println("GHIDRA_MCP_COMPATIBILITY_PASSED");
    }
}

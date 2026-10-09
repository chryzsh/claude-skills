// Ghidra headless script: export decompiled functions, imports, and strings
// Usage: analyzeHeadless ... -postScript ExportAll.java /output/dir
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.data.*;
import ghidra.program.model.address.*;
import java.io.*;

public class ExportAll extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("Usage: ExportAll.java <output_dir>");
            return;
        }
        String outDir = args[0];
        new File(outDir).mkdirs();

        String progName = currentProgram.getName().replaceAll("\\.[^.]+$", "");

        exportImports(outDir, progName);
        exportStrings(outDir, progName);
        exportDecompilation(outDir, progName);
    }

    private void exportImports(String outDir, String progName) throws Exception {
        File f = new File(outDir, progName + "-imports.txt");
        PrintWriter pw = new PrintWriter(f);
        SymbolTable st = currentProgram.getSymbolTable();
        SymbolIterator it = st.getExternalSymbols();
        while (it.hasNext()) {
            Symbol sym = it.next();
            Namespace ns = sym.getParentNamespace();
            pw.println(ns.getName() + "::" + sym.getName() + " @ " + sym.getAddress());
        }
        pw.close();
        println("Wrote imports to " + f.getAbsolutePath());
    }

    private void exportStrings(String outDir, String progName) throws Exception {
        File f = new File(outDir, progName + "-strings.txt");
        PrintWriter pw = new PrintWriter(f);
        DataIterator di = currentProgram.getListing().getDefinedData(true);
        while (di.hasNext()) {
            Data data = di.next();
            if (data.getDataType() instanceof StringDataType ||
                data.getDataType() instanceof UnicodeDataType ||
                data.getDataType() instanceof TerminatedStringDataType ||
                data.getDataType() instanceof TerminatedUnicodeDataType ||
                data.getDataType().getName().contains("unicode") ||
                data.getDataType().getName().contains("string")) {
                Object val = data.getValue();
                if (val != null) {
                    pw.println(data.getAddress() + " " + data.getDataType().getName() + " \"" + val.toString().replace("\n", "\\n") + "\"");
                }
            }
        }
        pw.close();
        println("Wrote strings to " + f.getAbsolutePath());
    }

    private void exportDecompilation(String outDir, String progName) throws Exception {
        File f = new File(outDir, progName + "-decompiled.c");
        PrintWriter pw = new PrintWriter(f);

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        FunctionIterator fi = currentProgram.getFunctionManager().getFunctions(true);
        int count = 0;
        while (fi.hasNext()) {
            Function func = fi.next();
            if (func.isThunk()) continue;

            DecompileResults results = decomp.decompileFunction(func, 30, monitor);
            if (results.getDecompiledFunction() != null) {
                pw.println("// Function: " + func.getName() + " @ " + func.getEntryPoint());
                pw.println(results.getDecompiledFunction().getC());
                pw.println();
                count++;
            }
        }

        decomp.dispose();
        pw.close();
        println("Decompiled " + count + " functions to " + f.getAbsolutePath());
    }
}

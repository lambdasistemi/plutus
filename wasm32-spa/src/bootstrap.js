import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";
import wasmBytes from "./assets/uplc.wasm";

const defaultProgram =
  "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])";

const compiledModulePromise = WebAssembly.compile(wasmBytes);

export async function runUplc(programText, withBudget) {
  const stdin = new OpenFile(new File(new TextEncoder().encode(programText)));
  const stdoutLines = [];
  const stderrLines = [];
  const stdout = ConsoleStdout.lineBuffered((line) => stdoutLines.push(line));
  const stderr = ConsoleStdout.lineBuffered((line) => stderrLines.push(line));
  const args = withBudget ? ["uplc", "evaluate", "-c"] : ["uplc", "evaluate"];

  const wasi = new WASI(args, [], [stdin, stdout, stderr]);
  const mod = await compiledModulePromise;
  const inst = await WebAssembly.instantiate(mod, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });

  let exitOk = true;
  try {
    wasi.start(inst);
  } catch (err) {
    const code = typeof err?.code === "number" ? err.code : undefined;
    exitOk = code === 0;
    if (!exitOk) {
      stderrLines.push(String(err));
    }
  }

  return {
    stdout: stdoutLines.join("\n"),
    stderr: stderrLines.join("\n"),
    exitOk,
  };
}

function renderOutput(result) {
  const sections = [];
  if (result.stdout) {
    sections.push(result.stdout);
  }
  if (result.stderr) {
    sections.push(`stderr:\n${result.stderr}`);
  }
  if (!sections.length) {
    sections.push(result.exitOk ? "(no output)" : "uplc exited without output");
  }
  return sections.join("\n\n");
}

function wireUi() {
  const program = document.querySelector("#program");
  const budget = document.querySelector("#budget");
  const button = document.querySelector("#evaluate");
  const output = document.querySelector("#output");
  const status = document.querySelector("#status");

  program.value = program.value.trim() || defaultProgram;

  button.addEventListener("click", async () => {
    button.disabled = true;
    status.textContent = "Evaluating...";
    output.textContent = "";

    try {
      const result = await runUplc(program.value, budget.checked);
      output.textContent = renderOutput(result);
      status.textContent = result.exitOk ? "Evaluation complete" : "uplc failed";
      output.classList.toggle("stderr", !result.exitOk);
    } catch (err) {
      output.textContent = String(err?.stack || err);
      output.classList.add("stderr");
      status.textContent = "Browser execution failed";
    } finally {
      button.disabled = false;
    }
  });
}

if (typeof window !== "undefined") {
  window.runUplc = runUplc;
  window.addEventListener("DOMContentLoaded", wireUi);
}

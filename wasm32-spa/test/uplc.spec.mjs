import { expect, test } from "@playwright/test";

const addIntegerProgram =
  "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])";

test("evaluates UPLC with the browser WASI CEK", async ({ page }) => {
  await page.goto("/");

  await page.getByLabel("UPLC program").fill(addIntegerProgram);
  await page.getByRole("button", { name: "Evaluate" }).click();

  const output = page.locator("#output");
  await expect(output).toContainText("(con integer 42)");

  await page.getByLabel("show budget (-c)").check();
  await page.getByRole("button", { name: "Evaluate" }).click();

  await expect(output).toContainText("(con integer 42)");
  await expect(output).toContainText("CPU budget");
  await expect(output).toContainText("Memory budget");

  const observed = await output.textContent();
  console.log(`observed output:\n${observed}`);
});

import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "People can tip and owner can withdraw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const alice = accounts.get("wallet_1")!;
    const bob = accounts.get("wallet_2")!;

    // Alice tips 50 STX
    let block = chain.mineBlock([
      Tx.contractCall("tipjar", "tip", [types.uint(50_000_000)], alice.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Bob tips 20 STX
    block = chain.mineBlock([
      Tx.contractCall("tipjar", "tip", [types.uint(20_000_000)], bob.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Check totals
    let total = chain.callReadOnlyFn("tipjar", "get-total", [], deployer.address);
    total.result.expectUint(70_000_000);

    let aliceTip = chain.callReadOnlyFn("tipjar", "get-tip", [types.principal(alice.address)], deployer.address);
    aliceTip.result.expectUint(50_000_000);

    // Owner withdraws 60 STX
    block = chain.mineBlock([
      Tx.contractCall("tipjar", "withdraw", [types.uint(60_000_000)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
  const INITIAL_DEPOSIT = BigInt(1000 * 10 ** 18);
  const INITIAL_DEPOSIT_USDT = BigInt(1000 * 10 ** 6);

  let sushiHolderAdd = "0xA74E8aE2F83d2564Af25420Ad4D6A7Fe224B053F",
    usdtHolderAdd = "0x88a1493366d48225fc3cefbdae9ebb23e323ade3",
    xSushiHolderAdd = "0x28a55C4b4f9615FDE3CDAdDf6cc01FcF2E38A6b0",
    xSushiAddress = "0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272",
    usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    sushiAddress = "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2",
    sushiHolder,
    usdtHolder,
    xSushiHolder,
    vault,
    vaultAdd,
    xSushiCon,
    usdtCon,
    sushiCon;

  // Helper to get shares
  async function approveToken(signer, tokenContract, amount) {
    return await tokenContract.connect(signer).approve(vaultAdd, amount);
  }

  async function getBalanceChange(signer, tokenContract, transactionCallback) {
    const balanceBefore = await tokenContract.balanceOf(signer.address);
    await transactionCallback();
    const balanceAfter = await tokenContract.balanceOf(signer.address);
    return balanceAfter - balanceBefore;
  }

  async function getShareChange(signer, transactionCallback) {
    const balanceBefore = await vault.shareHolder(signer.address);
    await transactionCallback();
    const balanceAfter = await vault.shareHolder(signer.address);
    return balanceAfter - balanceBefore;
  }

  it("Should deploy the contract", async function () {
    await helpers.impersonateAccount(sushiHolderAdd);
    await helpers.impersonateAccount(usdtHolderAdd);
    await helpers.impersonateAccount(xSushiHolderAdd);

    sushiHolder = await ethers.getSigner(sushiHolderAdd);
    usdtHolder = await ethers.getSigner(usdtHolderAdd);
    xSushiHolder = await ethers.getSigner(xSushiHolderAdd);

    usdtCon = await ethers.getContractAt("IERC20", usdtAddress, usdtHolder);
    xSushiCon = await ethers.getContractAt(
      "IERC20",
      xSushiAddress,
      xSushiHolder
    );
    sushiCon = await ethers.getContractAt("IERC20", sushiAddress, sushiHolder);

    const Vault = await ethers.getContractFactory("TokenVault");
    vault = await Vault.deploy(
      "0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272",
      "Sushi Shares",
      "ySushi"
    );

    vaultAdd = await vault.getAddress();
    console.log("Vault Contract Deployed at: ", await vault.getAddress());
  });

  it("should test the shares calculation for first time", async function () {
    await approveToken(xSushiHolder, xSushiCon, INITIAL_DEPOSIT);
    const balanceChange = await getShareChange(xSushiHolder, async () => {
      await vault
        .connect(xSushiHolder)
        ._deposit(INITIAL_DEPOSIT, xSushiAddress);
    });
    console.log(
      "Expected shares are: ",
      INITIAL_DEPOSIT,
      "Actual shares are: ",
      balanceChange
    );
    expect(balanceChange).to.equal(BigInt(INITIAL_DEPOSIT));
  });

  it("should test the shares calculation after first time", async function () {
    let totalAssets = await vault.totalAssets();
    let totalSupply = await vault.totalSupply(),
      expectedShares = (INITIAL_DEPOSIT * totalSupply) / totalAssets;
    await approveToken(xSushiHolder, xSushiCon, INITIAL_DEPOSIT);
    const balanceChange = await getShareChange(xSushiHolder, async () => {
      await vault
        .connect(xSushiHolder)
        ._deposit(INITIAL_DEPOSIT, xSushiAddress);
    });
    console.log(
      "Expected shares are: ",
      expectedShares,
      "Actual shares are: ",
      balanceChange
    );
    expect(balanceChange).to.equal(BigInt(expectedShares));
  });

  it("should test withdraw with xSushi", async function () {
    const shares = await vault.shareHolder(xSushiHolderAdd);
    const balanceChange = await getBalanceChange(
      xSushiHolder,
      xSushiCon,
      async () => {
        await vault
          .connect(xSushiHolder)
          ._withdraw(shares, xSushiHolderAdd, xSushiAddress);
      }
    );
    console.log(
      "Expected shares are: ",
      shares,
      "Actual shares are: ",
      balanceChange
    );
    expect(balanceChange).to.equal(shares);
  });

  it("should test the deposit function with USDT", async function () {
    this.timeout(60000);
    // check with usdt first
    await approveToken(usdtHolder, usdtCon, INITIAL_DEPOSIT_USDT);
    await vault.connect(usdtHolder)._deposit(INITIAL_DEPOSIT_USDT, usdtAddress);
  });

  it("should withdraw the tokens in USDT", async function () {
    const shares = await vault.shareHolder(usdtHolderAdd);
    const balanceChange = await getBalanceChange(
      usdtHolder,
      usdtCon,
      async () => {
        await vault
          .connect(usdtHolder)
          ._withdraw(shares, usdtHolderAdd, usdtAddress);
      }
    );
    console.log(
      "Expected shares are: ",
      INITIAL_DEPOSIT_USDT,
      "Actual shares are: ",
      balanceChange
    );
    expect(balanceChange).to.closeTo(INITIAL_DEPOSIT_USDT, 960 * 10 ** 6); // 96% slippage
  });

  it("should deposit the tokens in sushi", async function () {
    await approveToken(sushiHolder, sushiCon, INITIAL_DEPOSIT);
    await vault.connect(sushiHolder)._deposit(INITIAL_DEPOSIT, sushiAddress);
  });

  it("should withdraw the tokens in sushi", async function () {
    const shares = await vault.shareHolder(sushiHolderAdd);
    const balanceChange = await getBalanceChange(
      sushiHolder,
      sushiCon,
      async () => {
        await vault
          .connect(sushiHolder)
          ._withdraw(shares, sushiHolderAdd, sushiAddress);
      }
    );
    console.log(
      "Expected shares are: ",
      INITIAL_DEPOSIT,
      "Actual shares are: ",
      balanceChange
    );
    expect(balanceChange).to.closeTo(INITIAL_DEPOSIT, BigInt(0.001 * 10 ** 18)); // 0.0001% slippage
  });
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Treasury", function () {
  let owner;
  let alice;
  let usdc;
  let dai;
  let treasury;
  let uniswapRouter;

  const usdcDecimals = 6;
  const daiDecimals = 18;

  const usdcAmount = ethers.utils.parseUnits("10000", usdcDecimals);
  const daiAmount = ethers.utils.parseUnits("1000", daiDecimals);

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();

    // Deploy USDC and DAI mock tokens
    const MockToken = await ethers.getContractFactory("MockToken");
    usdc = await MockToken.deploy("USD Coin", "USDC", usdcDecimals);
    dai = await MockToken.deploy("Dai Stablecoin", "DAI", daiDecimals);

    // Deploy Uniswap router mock contract
    const UniswapRouterMock = await ethers.getContractFactory(
      "UniswapRouterMock"
    );
    uniswapRouter = await UniswapRouterMock.deploy();

    // Deploy Treasury contract
    const Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(
      usdc.address,
      dai.address,
      uniswapRouter.address
    );

    // Add protocol allocation to the treasury contract
    await treasury.addProtocol(alice.address, 50, alice.address, false);
    await treasury.addProtocol(owner.address, 50, owner.address, true);

    // Mint some USDC and DAI tokens to the owner
    await usdc.mint(owner.address, usdcAmount);
    await dai.mint(owner.address, daiAmount);

    // Approve USDC and DAI tokens to be spent by Treasury contract
    await usdc.approve(treasury.address, usdcAmount);
    await dai.approve(treasury.address, daiAmount);
  });

  it("should deposit tokens into the treasury and allocate them to the protocols", async function () {
    // Deposit 5000 USDC and 500 DAI to the Treasury contract
    await treasury.deposit(usdcAmount.div(2), usdc.address);
    await treasury.deposit(daiAmount.div(2), dai.address);

    // Check that the balances are allocated correctly

   
   
    // Check that the protocol allocations are correct

    // Trigger compounding of the protocol allocations


});

  it("should not allow anyone else to withdraw protocol allocations", async function () {
    // Try to withdraw protocol allocation as a non-protocol
    await expect(
      treasury
        .connect(alice)
        .withdrawProtocolAllocation(usdc.address, alice.address)
    ).to.be.revertedWith("only admin allowed");
  });

  it("should allow a protocol to withdraw its allocation", async function () {
    // Withdraw protocol allocation
    const initialBalance = await usdc.balanceOf(alice.address);
    await treasury.withdrawProtocolAllocation(usdc.address, alice.address);
    const finalBalance = await usdc.balanceOf(alice.address);

    // Check that the balance is updated correctly
    expect(finalBalance).to.equal(
      initialBalance.add(
        await treasury.getBalanceOfToken(usdc.address, alice.address)
      )
    );
  });

  it("should not allow a protocol to withdraw more than its allocation", async function () {
    // Try to withdraw more than the protocol allocation
    await expect(
      treasury.withdrawProtocolAllocation(
        usdc.address,
        alice.address,
        usdcAmount.add(1)
      )
    ).to.be.revertedWith("not in your balance");

    // Check that the balance is not affected
    expect(await usdc.balanceOf(alice.address)).to.equal(0);
  });

  

  it("should allow anyone other than owner to withdraw tokens from the treasury", async function () {
    // Withdraw tokens from the treasury
    const initialBalance = await usdc.balanceOf(alice.address);
    await treasury.withdraw(usdcAmount, usdc.address, alice.address);
    const finalBalance = await usdc.balanceOf(alice.address);

    // Check that the balance is updated correctly
    expect(finalBalance).to.equal(initialBalance.add(usdcAmount));
  });

  it("should not allow a protocol to withdraw more tokens than are available in the treasury", async function () {
    // Try to withdraw more tokens than are available
    await expect(
      treasury.withdraw(usdcAmount.add(1), usdc.address, alice.address)
    ).to.be.revertedWith("Treasury: insufficient balance");
  });
});

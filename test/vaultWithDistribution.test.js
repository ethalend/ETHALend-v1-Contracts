const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const TransferLogic = artifacts.require("TransferLogic");
const UniswapLogic = artifacts.require("UniswapLogic");
const InverseLogic = artifacts.require("InverseLogic");
const Vault = artifacts.require("Vault");
const Harvester = artifacts.require("Harvester");
const YTokenStrat = artifacts.require("YTokenStrat");
const IYToken = artifacts.require("IYToken");
const IYStrat = artifacts.require("IYStrat");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);
const DistributionFactory = artifacts.require("DistributionFactory");
const DistributionRewards = artifacts.require("DistributionRewards");

const {
  time,
  expectRevert,
  expectEvent,
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");
const { BN } = require("@openzeppelin/test-helpers/src/setup");
const { assert } = require("hardhat");

const hre = require("hardhat");

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

const FEE = 1000;
const REWARD_AMOUNT = toWei("1000");
const REWARD_DURATION = 86400; //1 DAY
const USER = "0x01Ec5e7e03e2835bB2d1aE8D2edDEd298780129c";
const USER2 = "0xC2C5A77d9f434F424Df3d39de9e90d95A0Df5Aca";
const MULTISIG = "0x9Fd332a4e9C7F2f0dbA90745c1324Cc170D16fE4";
const ETHA_HOLDER = "0xa1CEc90603405dA9578c88cDc8cAe7e098532DEa";

const YEARN_STRATEGIST = "0xc3d6880fd95e06c816cb030fac45b3ffe3651cb0";
const YEARN_LEV_COMP_STRAT = "0x4031afd3B0F71Bace9181E554A9E680Ee4AbE7dF";
const YEARN_AH_STRAT = "0x7D960F3313f3cB1BBB6BF67419d303597F3E2Fa8";
const YEARN_BLEV = "0x77b7CD137Dd9d94e7056f78308D7F65D2Ce68910";
const YEARN_OPTIMIZER = "0x32b8C26d0439e1959CEa6262CBabC12320b384c4";

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const YDAI_ADDRESS = "0x19D3364A399d251E894aC732651be8B0E4e85001";
const ETHA_ADDRESS = "0x59E9261255644c411AfDd00bD89162d09D862e38";

contract("Inverse Vaults", () => {
  let registry,
    wallet,
    wallet2,
    transfers,
    strat,
    uniswap,
    vault,
    inverse,
    yDai,
    genesis,
    factory,
    distribution,
    daiDistribution;

  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [YEARN_STRATEGIST],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [USER],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [USER2],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [MULTISIG],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ETHA_HOLDER],
    });

    etha = await IERC20.at(ETHA_ADDRESS);
    dai = await IERC20.at(DAI_ADDRESS);
    yDai = await IYToken.at(YDAI_ADDRESS);

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    uniswap = await UniswapLogic.new();
    inverse = await InverseLogic.new();
    smartWalletImpl = await SmartWallet.new();

    const proxy = await upgrades.deployProxy(EthaRegistry, [
      smartWalletImpl.address,
      MULTISIG,
      MULTISIG,
      FEE,
    ]);

    registry = await EthaRegistryTruffle.at(proxy.address);

    await registry.enableLogicMultiple([
      transfers.address,
      uniswap.address,
      inverse.address,
    ]);

    // Smart Wallet Creation
    await registry.deployWallet({ from: USER });
    const swAddress = await registry.wallets(USER);
    wallet = await SmartWallet.at(swAddress);

    await registry.deployWallet({ from: USER2 });
    const swAddress2 = await registry.wallets(USER2);
    wallet2 = await SmartWallet.at(swAddress2);

    // Deposit DAI
    await dai.transfer(swAddress, toWei(200), { from: USER });
    await dai.transfer(swAddress2, toWei(200), { from: USER2 });

    // Fund Mulsitig with ETH
    await web3.eth.sendTransaction({
      from: USER,
      to: MULTISIG,
      value: toWei(0.5),
    });
  });

  it("should deploy the Harvester contract", async function () {
    harvester = await Harvester.new();
  });

  it("should deploy the vault contract", async function () {
    vault = await Vault.new(
      DAI_ADDRESS,
      WETH_ADDRESS,
      harvester.address,
      "Test DAI to ETH Vault",
      "testDAI>ETH"
    );
    genesis = Number(await time.latest()) + 15;

    factory = await DistributionFactory.new(ETHA_ADDRESS, genesis, vault.address);

    await factory.deploy(
      DAI_ADDRESS,
      REWARD_AMOUNT,
      REWARD_DURATION
    );

    daiDistribution = await factory.stakingRewardsInfoByStakingToken(DAI_ADDRESS);
    daiDistribution = daiDistribution.stakingRewards

    vault.updateDistribution(daiDistribution);

    await etha.transfer(factory.address, REWARD_AMOUNT, { from: ETHA_HOLDER });

    await time.increase(15);

    await factory.notifyRewardAmounts();

    distribution = await DistributionRewards.at(daiDistribution);
  });

  it("should deploy the YTokenStrat contract", async function () {
    strat = await YTokenStrat.new(vault.address, YDAI_ADDRESS);
  });

  it("Should connect Strat to Vault", async function () {
    await vault.setStrat(strat.address, false);
    assert.equal(await vault.strat(), strat.address);
    assert.equal(await vault.paused(), false);
  });

  it("Should deposit DAI to vault", async function () {
    await strat.totalYearnDeposits();

    const daiBalance = await dai.balanceOf(wallet.address);
    assert.equal(daiBalance, toWei(200));

    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "deposit",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    let stakedBalance = await distribution.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
    assert(fromWei(stakedBalance) == fromWei(vaultTokenBalance));
    await time.increase(3600);
    let earnedBalance = await distribution.earned(wallet.address);
    assert(fromWei(earnedBalance) > 0);
  });

  it("should only allow vaults to stake/withdraw", async function () {
    await expectRevert(
      distribution.stake(USER, toWei("1000"),{from: USER}),
      "Invalid Access: Can only be accessed by ETHA Vaults"
    );
    await expectRevert(
      distribution.withdraw(USER, toWei("1000"),{from: USER}),
      "Invalid Access: Can only be accessed by ETHA Vaults"
    );
  });

  it("Should deposit DAI to vault starting with ETH", async function () {
    await strat.totalYearnDeposits();

    const data1 = web3.eth.abi.encodeFunctionCall(
      {
        name: "swapV2",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "fromToken",
          },
          {
            type: "address",
            name: "destToken",
          },
          {
            type: "uint256",
            name: "amount",
          },
        ],
      },
      [ETH_ADDRESS, DAI_ADDRESS, toWei(1)]
    );

    const data2 = web3.eth.abi.encodeFunctionCall(
      {
        name: "deposit",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    const tx = await wallet.execute(
      [uniswap.address, inverse.address],
      [data1, data2],
      false,
      {
        from: USER,
        gas: web3.utils.toHex(5e6),
        value: toWei(1),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
  });

  it("Should deposit DAI to vault using waiting functionality", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "depositAndWait",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    let tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    tx = await wallet2.execute([inverse.address], [data], false, {
      from: USER2,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);
  });

  it("Should mint pending vault tokens (waiting)", async function () {
    const initialBalance = await vault.balanceOf(wallet.address);
    const initialBalance2 = await vault.balanceOf(wallet2.address);

    const tx = await vault.mintPending({
      from: USER2,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const finalBalance = await vault.balanceOf(wallet.address);
    const finalBalance2 = await vault.balanceOf(wallet2.address);

    assert(fromWei(finalBalance) > fromWei(initialBalance));
    assert(fromWei(finalBalance2) > fromWei(initialBalance2));
  });

  it("Should withdraw DAI from vault", async function () {
    const startDaiBalance = await dai.balanceOf(wallet.address);

    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "withdraw",
        type: "function",
        inputs: [
          {
            type: "uint256",
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [String(50e18), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const endDaiBalance = await dai.balanceOf(wallet.address);
    assert.equal(
      new BN(endDaiBalance).sub(new BN(startDaiBalance)),
      String(50e18)
    );
  });

  it("Should harvest profits for yDAI vault", async function () {
    let pps = await yDai.pricePerShare();
    console.log("\tpps before:", fromWei(pps));
    await time.advanceBlock();

    const STRATS = [
      YEARN_LEV_COMP_STRAT,
      YEARN_AH_STRAT,
      YEARN_BLEV,
      YEARN_OPTIMIZER,
    ];

    for (const i in STRATS) {
      const yearnStrat = await IYStrat.at(STRATS[i]);
      const tx = await yearnStrat.harvest({ from: YEARN_STRATEGIST });
      const { profit, loss } = tx.receipt.logs[0].args;
      console.log(
        `\tStrat #${i}`,
        "profit:",
        fromWei(profit),
        "loss:",
        fromWei(loss)
      );
    }

    pps = await yDai.pricePerShare();
    console.log("\tpps after:", fromWei(pps));
  });

  it("Should have profits in ETHA vault", async function () {
    const totalValue = await strat.calcTotalValue();
    const totalSupply = await vault.totalSupply();

    assert(totalValue > totalSupply);
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await time.advanceBlock();

    const now = Number(await time.latest());

    await harvester.harvestVault(
      vault.address,
      toWei(0.01),
      1,
      [DAI_ADDRESS, WETH_ADDRESS],
      now + 1
    );
  });

  it("Should claim ETH profits from vault", async function () {
    const weth = await IERC20.at(WETH_ADDRESS);
    const startETHBalance = await weth.balanceOf(wallet.address);

    let userEthaBalance = await etha.balanceOf(wallet.address);
    console.log('etha balance before claiming ETH profits from vault', fromWei(userEthaBalance));

    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "claim",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const endETHBalance = await weth.balanceOf(wallet.address);
    userEthaBalance = await etha.balanceOf(wallet.address);
    console.log('user Etha Balance after claiming ETH profits from vault',fromWei(userEthaBalance));
    assert(new BN(endETHBalance).sub(new BN(startETHBalance)) > 0);
    assert(fromWei(userEthaBalance) > 0);
  });
});

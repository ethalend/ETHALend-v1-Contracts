const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const TransferLogic = artifacts.require("TransferLogic");
const UniswapLogic = artifacts.require("UniswapLogic");
const InverseLogic = artifacts.require("InverseLogic");
const EthWrapLogic = artifacts.require("EthWrapLogic");
const Vault = artifacts.require("Vault");
const Harvester = artifacts.require("Harvester");
const YTokenStrat = artifacts.require("YTokenStrat");
const IYToken = artifacts.require("IYToken");
const IYStrat = artifacts.require("IYStrat");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const {
  expectRevert,
  time,
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");
const { BN } = require("@openzeppelin/test-helpers/src/setup");
const { assert } = require("hardhat");

const hre = require("hardhat");

const FEE = 1000;

const YEARN_STRATEGIST = "0x710295b5f326c2e47e6dd2e7f6b5b0f7c5ac2f24";
const YEARN_STRATEGIST2 = "0xc3d6880fd95e06c816cb030fac45b3ffe3651cb0";

const YEARN_STRATS = [
  "0x2886971eCAF2610236b4869f58cD42c115DFb47A",
  "0xcCA83Ea686F42d45B9DE5b5cA668962Cd4a30C2E",
];
const YEARN_STRATS2 = ["0xeE697232DF2226c9fB3F02a57062c4208f287851"];

// TOKENS
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const UNI_ADDRESS = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";

const YETH_ADDRESS = "0xa9fE4601811213c340e850ea305481afF02f5b28";

const WETH_HOLDER = "0x4a18a50a8328b42773268B4b436254056b7d70CE";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("yETH Vault", ([multisig, alice]) => {
  let registry,
    wallet,
    transfers,
    ethWrap,
    strat,
    uniswap,
    vault,
    inverse,
    yEth,
    weth,
    uni;

  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
            blockNumber: 12280000,
          },
        },
      ],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [WETH_HOLDER],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [YEARN_STRATEGIST],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [YEARN_STRATEGIST2],
    });

    yEth = await IYToken.at(YETH_ADDRESS);
    weth = await IERC20.at(WETH_ADDRESS);
    uni = await IERC20.at(UNI_ADDRESS);

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    uniswap = await UniswapLogic.new();
    inverse = await InverseLogic.new();
    ethWrap = await EthWrapLogic.new();
    smartWalletImpl = await SmartWallet.new();

    const proxy = await upgrades.deployProxy(EthaRegistry, [
      smartWalletImpl.address,
      multisig,
      multisig,
      FEE,
    ]);

    registry = await EthaRegistryTruffle.at(proxy.address);

    await registry.enableLogicMultiple([
      transfers.address,
      uniswap.address,
      inverse.address,
      ethWrap.address,
    ]);

    // Smart Wallet Creation
    await registry.deployWallet({ from: alice });
    const swAddress = await registry.wallets(alice);
    wallet = await SmartWallet.at(swAddress);
  });

  it("should deploy the Harvester contract", async function () {
    harvester = await Harvester.new(Number(time.duration.hours(2)));
  });

  it("should deploy the vault contract", async function () {
    vault = await Vault.new(
      WETH_ADDRESS,
      UNI_ADDRESS,
      harvester.address,
      "ETHA ETH/UNI Pool",
      "eETHUNI"
    );
  });

  it("should deploy the YTokenStrat contract", async function () {
    strat = await YTokenStrat.new(vault.address, YETH_ADDRESS);
  });

  it("Should connect Strat to Vault", async function () {
    await vault.setStrat(strat.address, false);
    assert.equal(await vault.strat(), strat.address);
    assert.equal(await vault.paused(), false);
  });

  it("Should deposit to vault starting with ETH", async function () {
    await strat.totalYearnDeposits();

    const data1 = web3.eth.abi.encodeFunctionCall(
      {
        name: "wrap",
        type: "function",
        inputs: [
          {
            type: "uint256",
            name: "amount",
          },
        ],
      },
      [toWei(10)]
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
      [WETH_ADDRESS, toWei(10), vault.address]
    );

    const tx = await wallet.execute(
      [ethWrap.address, inverse.address],
      [data1, data2],
      false,
      {
        from: alice,
        gas: web3.utils.toHex(5e6),
        value: toWei(10),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert.equal(vaultTokenBalance, toWei(10));
  });

  it("Should deposit WETH to vault", async function () {
    await strat.totalYearnDeposits();

    await weth.transfer(wallet.address, toWei(5), { from: WETH_HOLDER });

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
      [WETH_ADDRESS, toWei(5), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: alice,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert.equal(vaultTokenBalance, toWei(15));
  });

  it("Should withdraw WETH from vault", async function () {
    await time.advanceBlock();

    const startWETHBalance = await weth.balanceOf(wallet.address);

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
      [toWei(1), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: alice,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const endWETHBalance = await weth.balanceOf(wallet.address);
    assert.equal(
      new BN(endWETHBalance).sub(new BN(startWETHBalance)),
      toWei(1)
    );
  });

  it.skip("Should harvest profits for yWETH vault", async function () {
    const ppsStart = await yEth.pricePerShare();
    console.log("\tpps before:", fromWei(ppsStart));

    for (const i in YEARN_STRATS) {
      const yearnStrat = await IYStrat.at(YEARN_STRATS[i]);
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

    for (const i in YEARN_STRATS2) {
      const yearnStrat = await IYStrat.at(YEARN_STRATS2[i]);
      const tx = await yearnStrat.harvest({ from: YEARN_STRATEGIST2 });
      const { profit, loss } = tx.receipt.logs[0].args;
      console.log(
        `\tStrat #${i}`,
        "profit:",
        fromWei(profit),
        "loss:",
        fromWei(loss)
      );
    }

    const ppsEnd = await yEth.pricePerShare();
    console.log("\tpps after:", fromWei(ppsEnd));

    assert(ppsEnd > ppsStart, "PPS lower after harvest");
  });

  it("Should have profits in ETHA vault ", async function () {
    // Avoid yearn harvest, alter calculation of total value;
    await weth.transfer(strat.address, toWei(5), { from: WETH_HOLDER });

    const totalValue = await strat.calcTotalValue();
    const totalSupply = await vault.totalSupply();

    assert(fromWei(totalValue) > fromWei(totalSupply));
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await harvester.harvestVault(vault.address, { from: alice });
  });

  it("Should have profits in ETHA vault (again)", async function () {
    // Avoid yearn harvest, alter calculation of total value;
    await weth.transfer(strat.address, toWei(5), { from: WETH_HOLDER });

    const totalValue = await strat.calcTotalValue();
    const totalSupply = await vault.totalSupply();

    assert(fromWei(totalValue) > fromWei(totalSupply));
  });

  it("Should harvest profits in ETHA Vault only after delay", async function () {
    await time.advanceBlock();

    let now = Number(await time.latest());

    await expectRevert(
      harvester.harvestVault(vault.address, { from: alice }),
      "Not ready to harvest"
    );

    await time.increase(time.duration.hours(2));
    now = Number(await time.latest());

    await harvester.harvestVault(vault.address, { from: alice });
  });

  it("Should claim UNI profits from vault", async function () {
    const startUNIBalance = await uni.balanceOf(wallet.address);

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
      from: alice,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const endUNIBalance = await uni.balanceOf(wallet.address);

    assert(new BN(endUNIBalance).sub(new BN(startUNIBalance)) > 0);
  });
});

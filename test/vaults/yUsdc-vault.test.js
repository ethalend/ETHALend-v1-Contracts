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

const {
  expectRevert,
  time,
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");
const { BN } = require("@openzeppelin/test-helpers/src/setup");
const { assert } = require("hardhat");

const hre = require("hardhat");

const FEE = 1000;
const USDC_HOLDER = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8";

const YEARN_STRATEGIST = "0xc3d6880fd95e06c816cb030fac45b3ffe3651cb0";
const YEARN_STRATEGIST2 = "0xd0579bc5c0f839ea2bcc79bb127e2f39801903e2";

const YEARN_STRATS = [
  "0x4D7d4485fD600c61d840ccbeC328BfD76A050F87",
  "0x86Aa49bf28d03B1A4aBEb83872cFC13c89eB4beD",
];
const YEARN_STRATS2 = ["0x79B3D0A9513C49D7Ea4BD6868a08aD966eC18f46"];

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const YUSDC_ADDRESS = "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("yUSDC Vault", ([multisig, alice]) => {
  let registry, wallet, transfers, strat, uniswap, vault, inverse, usdc, yUsdc;

  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
            blockNumber: 12284000,
          },
        },
      ],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [YEARN_STRATEGIST],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [YEARN_STRATEGIST2],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [USDC_HOLDER],
    });

    usdc = await IERC20.at(USDC_ADDRESS);
    yUsdc = await IYToken.at(YUSDC_ADDRESS);

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    uniswap = await UniswapLogic.new();
    inverse = await InverseLogic.new();
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
    ]);

    // Smart Wallet Creation
    await registry.deployWallet({ from: alice });
    const swAddress = await registry.wallets(alice);
    wallet = await SmartWallet.at(swAddress);

    // Fund USDC Holder with ETH
    await web3.eth.sendTransaction({
      from: multisig,
      to: USDC_HOLDER,
      value: toWei(0.5),
    });

    // Get USDC Tokens
    await usdc.transfer(swAddress, String(200e6), { from: USDC_HOLDER });
  });

  it("should deploy the Harvester contract", async function () {
    harvester = await Harvester.new(Number(time.duration.hours(2)));
  });

  it("should deploy the vault contract", async function () {
    vault = await Vault.new(
      USDC_ADDRESS,
      WETH_ADDRESS,
      harvester.address,
      "ETHA USDC/ETH Pool",
      "eUSDCETH"
    );
  });

  it("should deploy the YTokenStrat contract", async function () {
    strat = await YTokenStrat.new(vault.address, YUSDC_ADDRESS);
  });

  it("Should connect Strat to Vault", async function () {
    await vault.setStrat(strat.address, false);
    assert.equal(await vault.strat(), strat.address);
    assert.equal(await vault.paused(), false);
  });

  it("Should deposit USDC to vault", async function () {
    await strat.totalYearnDeposits();

    const usdcBalance = await usdc.balanceOf(wallet.address);
    assert.equal(usdcBalance, 200e6);

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
      [USDC_ADDRESS, String(50e6), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: alice,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
  });

  it("Should deposit USDC to vault starting with ETH", async function () {
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
      [ETH_ADDRESS, USDC_ADDRESS, toWei(1)]
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
      [USDC_ADDRESS, String(50e6), vault.address]
    );

    const tx = await wallet.execute(
      [uniswap.address, inverse.address],
      [data1, data2],
      false,
      {
        from: alice,
        gas: web3.utils.toHex(5e6),
        value: toWei(1),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
  });

  it("Should withdraw USDC from vault", async function () {
    const startUsdcBalance = await usdc.balanceOf(wallet.address);

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
      [String(50e6), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: alice,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const endUsdcBalance = await usdc.balanceOf(wallet.address);
    assert.equal(
      new BN(endUsdcBalance).sub(new BN(startUsdcBalance)),
      String(50e6)
    );
  });

  it.skip("Should harvest profits for yUSDC vault", async function () {
    const ppsStart = await yUsdc.pricePerShare();
    console.log("\tpps before:", ppsStart * 1e-6);
    await time.advanceBlock();

    for (const i in YEARN_STRATS) {
      const yearnStrat = await IYStrat.at(YEARN_STRATS[i]);
      const tx = await yearnStrat.harvest({ from: YEARN_STRATEGIST });
      const { profit, loss } = tx.receipt.logs[0].args;
      console.log(
        `\tStrat #${i}`,
        "profit:",
        profit * 1e-6,
        "loss:",
        loss * 1e-6
      );
    }

    for (const i in YEARN_STRATS2) {
      const yearnStrat = await IYStrat.at(YEARN_STRATS2[i]);
      const tx = await yearnStrat.harvest({ from: YEARN_STRATEGIST2 });
      const { profit, loss } = tx.receipt.logs[0].args;
      console.log(
        `\tStrat #${i}`,
        "profit:",
        profit * 1e-6,
        "loss:",
        loss * 1e-6
      );
    }

    const ppsEnd = await yUsdc.pricePerShare();
    console.log("\tpps after:", ppsEnd * 1e-6);

    assert(ppsEnd > ppsStart, "PPS lower after harvest");
  });

  it("Should have profits in ETHA vault", async function () {
    // Avoid yearn harvest, alter calculation of total value;
    await usdc.transfer(strat.address, String(200e6), { from: USDC_HOLDER });

    const totalValue = await strat.calcTotalValue();
    const totalSupply = await vault.totalSupply();

    assert(fromWei(totalValue) > fromWei(totalSupply));
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await harvester.harvestVault(vault.address, { from: alice });
  });

  it("Should have profits in ETHA vault (again)", async function () {
    // Avoid yearn harvest, alter calculation of total value;
    await usdc.transfer(strat.address, String(200e6), { from: USDC_HOLDER });

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

  it("Should claim ETH profits from vault", async function () {
    const weth = await IERC20.at(WETH_ADDRESS);
    const startETHBalance = await weth.balanceOf(wallet.address);

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

    const endETHBalance = await weth.balanceOf(wallet.address);

    assert(new BN(endETHBalance).sub(new BN(startETHBalance)) > 0);
  });
});

const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const InverseLogic = artifacts.require("InverseLogic");
const CurveLogic = artifacts.require("CurveLogic");
const Vault = artifacts.require("Vault");
const Harvester = artifacts.require("Harvester");
const YTokenStrat = artifacts.require("YTokenStrat");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const FEE = 1000;

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const UNI_ADDRESS = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984";
const YVAULT_ADDRESS = "0xdCD90C7f6324cfa40d7169ef80b12031770B4325";
const STETH_CRV_ADDRESS = "0xDC24316b9AE028F1497c275EB9192a3Ea0f67022";
const CURVE_LP_TOKEN = "0x06325440D014e39736583c165C2963BA99fAf14E";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("Inverse Vaults", ([multisig, alice]) => {
  let registry, wallet, curve, inverse, strat, vault, lpToken;

  before(async function () {
    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    inverse = await InverseLogic.new();
    curve = await CurveLogic.new();
    smartWalletImpl = await SmartWallet.new();
    lpToken = await IERC20.at(CURVE_LP_TOKEN);

    const proxy = await upgrades.deployProxy(EthaRegistry, [
      smartWalletImpl.address,
      multisig,
      multisig,
      FEE,
    ]);

    registry = await EthaRegistryTruffle.at(proxy.address);

    await registry.enableLogicMultiple([inverse.address, curve.address]);

    // Smart Wallet Creation
    await registry.deployWallet({ from: alice });
    const swAddress = await registry.wallets(alice);
    wallet = await SmartWallet.at(swAddress);
  });

  it("should deploy the Harvester contract", async function () {
    harvester = await Harvester.new();
  });

  it("should deploy the vault contract", async function () {
    vault = await Vault.new(
      CURVE_LP_TOKEN,
      UNI_ADDRESS,
      harvester.address,
      "Test ETH to UNI Vault",
      "testETH>UNI"
    );
  });

  it("should deploy the YTokenStrat contract", async function () {
    strat = await YTokenStrat.new(vault.address, YVAULT_ADDRESS);
  });

  it("Should connect Strat to Vault", async function () {
    await vault.setStrat(strat.address, false);
    assert.equal(await vault.strat(), strat.address);
    assert.equal(await vault.paused(), false);
  });

  it("Should deposit ETH to vault using curve", async function () {
    const data1 = web3.eth.abi.encodeFunctionCall(
      {
        name: "addLiquidity",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "curveToken",
          },
          {
            type: "address",
            name: "underlying",
          },
          {
            type: "uint256",
            name: "amount",
          },
          {
            type: "uint256",
            name: "tokenId",
          },
        ],
      },
      [STETH_CRV_ADDRESS, ETH_ADDRESS, toWei(1), 0]
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
            name: "amount",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [CURVE_LP_TOKEN, toWei(1), vault.address]
    );

    const tx = await wallet.execute(
      [curve.address, inverse.address],
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
});

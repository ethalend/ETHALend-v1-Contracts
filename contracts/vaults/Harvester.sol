//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;
import "../interfaces/IVault.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ICurveTwo.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

contract Harvester is Ownable {
    using SafeMath for uint256;
    IUniswapV2Router constant ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IWETH constant WETH = IWETH(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping (IVault => uint) public ratePerToken;

    /**
     * @dev unlimited approval
     */
    function setApproval(
        address erc20,
        uint256 srcAmt,
        address to
    ) internal {
        uint256 tokenAllowance = IERC20(erc20).allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            IERC20(erc20).approve(to, uint(-1));
        }
    }       

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public onlyOwner {
        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());
        IERC20Detailed from = vault.underlying();

        console.log(address(from));

        if(address(from) == ETH_ADDRESS) {
            require(path[0] == address(WETH));
            WETH.deposit{value:amount}();
            from = IERC20Detailed(address(WETH));
        }       

        console.log(from.balanceOf(address(this)));

        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        IERC20 to = vault.target();

        setApproval(address(from), afterFee, address(ROUTER));
        uint received = ROUTER.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[path.length-1];
        to.approve(address(vault), received);
        vault.distribute(received);
    }

    function harvestVaultCurve(IVault vault, uint amount, address[] calldata path, ICurveTwo curvePool, address baseToken) public onlyOwner {
        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());
        IERC20 curveToken = IERC20(address(vault.underlying()));
        IERC20 target = vault.target();

        require(path[path.length-1] == address(target));

        // Remove Liquidity from Curve pool
        uint256[2] memory _amts;
        _amts[0] = curvePool.calc_withdraw_one_coin(
            afterFee,
            0
        );
        setApproval(address(curveToken), _amts[0], address(curvePool));
        curvePool.remove_liquidity_imbalance(_amts, uint(-1));

        IERC20Detailed from = IERC20Detailed(baseToken);

        if(address(baseToken) == ETH_ADDRESS) {
            require(path[0] == address(WETH));
            WETH.deposit{value:address(this).balance}();
            from = IERC20Detailed(address(WETH));
        }

        afterFee = from.balanceOf(address(this));
        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        
        // Swap in Uniswap
        setApproval(address(from), afterFee, address(ROUTER));
        uint received = ROUTER.swapExactTokensForTokens(afterFee, 1, path, address(this), block.timestamp+1)[path.length-1];
        
        // Send swapped tokens to Vault
        setApproval(address(target), received, address(vault));
        vault.distribute(received);
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

    receive() external payable{}

}
//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;
import "../interfaces/IVault.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IOneSplit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

contract Harvester is Ownable {
    using SafeMath for uint256;

    event Harvested(address indexed vault, address indexed sender);

    IUniswapV2Router constant ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IOneSplit split = IOneSplit(0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E); // 1split.eth

    mapping (IVault => uint) public ratePerToken;

    uint public delay;

    constructor(uint _delay){
        delay = _delay;
    }

    modifier onlyAfterDelay(IVault vault){
        require(block.timestamp >= vault.lastDistribution().add(delay), "Not ready to harvest");
        _;
    }

    /**
        @notice Harvest vault using uniswap
        @dev any user can harvest after delay has passed
     */
    function harvestVault(IVault vault) public onlyAfterDelay(vault) {
        // Amount to Harvest
        uint amount = vault.underlyingYield();
        require(amount > 0, "!Yield");

        // Uniswap path
        address[] memory path = new address[](2);
        path[0] = address(vault.underlying());
        path[1] = address(vault.target());

        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());

        IERC20Detailed from = vault.underlying();
        require(path[0] == address(from), "Incorrect underlying");

        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        
        IERC20 to = vault.target();
        require(path[path.length-1] == address(to), "Incorrect target");

        from.approve(address(ROUTER), afterFee);
        uint received = ROUTER.swapExactTokensForTokens(afterFee, 1, path, address(this), block.timestamp+1)[path.length-1];
        to.approve(address(vault), received);

        vault.distribute(received);       

        emit Harvested(address(vault), msg.sender);
    }

    /**
        @notice Harvest vault using uniswap
        @dev only owner
     */
    function harvestVaultOwner(
        IVault vault, 
        uint amount, 
        uint outMin, 
        address[] calldata path, 
        uint deadline
    ) public onlyOwner onlyAfterDelay(vault) {
        require(amount > 0, "amount not zero");

        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());

        IERC20Detailed from = vault.underlying();
        require(path[0] == address(from), "Incorrect underlying");

        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        
        IERC20 to = vault.target();
        require(path[path.length-1] == address(to), "Incorrect target");

        from.approve(address(ROUTER), afterFee);
        uint received = ROUTER.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[path.length-1];
        to.approve(address(vault), received);

        vault.distribute(received);

        emit Harvested(address(vault), msg.sender);
    }

    /**
        @notice Harvest vault using 1inch swap
        @dev only owner
     */
    function harvestVaultOwner2(
        IVault vault, 
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
         uint256 flags
    ) public onlyOwner onlyAfterDelay(vault) {
        require(amount > 0, "amount not zero");

        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());

        // Tokens to swap
        IERC20 src = vault.underlying();
        IERC20 dest = vault.target();

        ratePerToken[vault] = afterFee.mul(10**(36-IERC20Detailed(address(src)).decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);

        src.approve(address(split), afterFee);
        uint returnAmount = split.swap(src, dest, amount, minReturn, distribution, flags);
        dest.approve(address(vault), returnAmount);

        vault.distribute(returnAmount);

        emit Harvested(address(vault), msg.sender);
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}
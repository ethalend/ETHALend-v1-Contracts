//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;
import "../interfaces/IVault.sol";
import "../interfaces/IUniswapV2Router.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

contract Harvester is Ownable {
    using SafeMath for uint256;

    event Harvested(address indexed vault, address indexed sender);

    IUniswapV2Router constant ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    mapping (IVault => uint) public ratePerToken;

    mapping (IVault => uint) public lastHarvest;

    uint public delay;

    constructor(uint _delay){
        delay = _delay;
    }

    modifier onlyAfterDelay(IVault vault){
        require(block.timestamp >= lastHarvest[vault].add(delay), "Not ready to harvest");
        _;
    }

    function harvestVault(IVault vault) public onlyAfterDelay(vault) {
        lastHarvest[vault] = block.timestamp;

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

    function harvestVaultOwner(
        IVault vault, 
        uint amount, 
        uint outMin, 
        address[] calldata path, 
        uint deadline
    ) public onlyOwner onlyAfterDelay(vault) {
        require(amount > 0, "amount not zero");

        lastHarvest[vault] = block.timestamp;

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

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}
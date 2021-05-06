//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;
import "../interfaces/IVault.sol";
import "../interfaces/IUniswapV2Router.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

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

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public onlyAfterDelay(vault) {
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

        lastHarvest[vault] = block.timestamp;

        Harvested(address(vault), msg.sender);
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}
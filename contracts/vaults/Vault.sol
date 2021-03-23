//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "../interfaces/IStrat.sol";
import "../interfaces/IVault.sol";
import "./DividendToken.sol";
import "../libs/Timelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "hardhat/console.sol";

contract Vault is Ownable, Pausable, DividendToken {
    using SafeMath for uint256;
    using SafeERC20 for IERC20Detailed;

    IERC20Detailed public underlying;
    IStrat public strat;
    Timelock public timelock;

    address public harvester;
    uint constant MAX_FEE = 10000;
    uint public performanceFee = 0; // 0% of profit
    // if depositLimit = 0 then there is no deposit limit
    uint public depositLimit;
    uint public lastDistribution;    
    uint256 public pendingTotal = 0;
    mapping(address => uint256) public pending;
    address[] public addressesPendingForMinting;

    // EVENTS
    event HarvesterChanged(address newHarvester);
    event FeeUpdate(uint256 newFee);
    event StrategyChanged(address newStrat);
    event DepositLimitUpdated(uint newLimit);

    modifier onlyHarvester {
        require(msg.sender == harvester);
        _;
    }

    constructor(IERC20Detailed underlying_, IERC20 reward_, address harvester_, string memory name_, string memory symbol_)
    DividendToken(reward_, name_, symbol_, 18)
    {
        underlying = underlying_;
        harvester = harvester_;
        depositLimit = 20000 * (10**18); // 20k initial deposit limit
        timelock = new Timelock(msg.sender, 2 days);
        _pause(); // paused until a strategy is connected
    }

    function calcTotalValue() public returns (uint underlyingAmount) {
        return strat.calcTotalValue();
    }

    function deposit(uint amount) external whenNotPaused {
        require(amount > 0, "ZERO-AMOUNT");
        if(depositLimit > 0) { // if deposit limit is 0, then there is no deposit limit
            require(totalSupply().add(amount) <= depositLimit);
        }
        underlying.safeTransferFrom(msg.sender, address(strat), amount);
        strat.invest();
        _mint(msg.sender, amount);
    }

    function depositAndWait(uint amount) external whenNotPaused {
        require(amount > 0, "ZERO-AMOUNT");
        if(depositLimit > 0) { // if deposit limit is 0, then there is no deposit limit
            require(totalSupply().add(amount) <= depositLimit);
        }
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        pendingTotal = pendingTotal.add(amount);
        pending[msg.sender] = (pending[msg.sender]).add(amount);
        addressesPendingForMinting.push(msg.sender);
    }

    function withdraw(uint amount) external {
        require(amount > 0, "ZERO-AMOUNT");
        _burn(msg.sender, amount);
        strat.divest(amount);
        underlying.safeTransfer(msg.sender, amount);
    }

    function withdrawPending(uint amount) external {
        require(amount > 0, "ZERO-AMOUNT");
        require(amount >= pending[msg.sender], 'Withdrawal Amount Greater Than Deposited');
        pendingTotal = pendingTotal.sub(amount);
        pending[msg.sender] = (pending[msg.sender]).sub(amount);
        underlying.safeTransfer(msg.sender, amount);
    }

    function mintPending() external{
      underlying.safeTransfer(address(strat), pendingTotal);
      strat.invest();
      pendingTotal = 0;
      for(uint256 i = 0; i< addressesPendingForMinting.length; i++){
        if(pending[addressesPendingForMinting[i]] > 0){
            _mint(addressesPendingForMinting[i], pending[addressesPendingForMinting[i]]);
            pending[addressesPendingForMinting[i]] = 0;
        }
      }
      delete addressesPendingForMinting;
    }

    function underlyingYield() public returns (uint) {
        return calcTotalValue().sub(totalSupply());
    }

    function unclaimedProfit(address user) external view returns (uint256) {
        return withdrawableDividendOf(user);
    }

    function claim() external {
        withdrawDividend(msg.sender);
    }

    // Used to claim on behalf of certain contracts e.g. Uniswap pool
    function claimOnBehalf(address recipient) external {
        require(msg.sender == harvester || msg.sender == owner());
        withdrawDividend(recipient);
    }

    function pauseDeposits(bool trigger) external onlyOwner {
        if(trigger) _pause();
        else _unpause();
    }

    function changeHarvester(address harvester_) external onlyOwner {
        harvester = harvester_;

        emit HarvesterChanged(harvester_);
    }

    function changePerformanceFee(uint fee_) external onlyOwner {
        require(fee_ <= MAX_FEE);
        performanceFee = fee_;

        emit FeeUpdate(fee_);
    }

    // The owner has to wait 2 days to confirm changing the strat.
    // This protects users from an upgrade to a malicious strategy
    // Users must watch the timelock contract on Etherscan for any transactions
    function setStrat(IStrat strat_, bool force) external {
        if(address(strat) != address(0)) {
            require(msg.sender == address(timelock));
            uint prevTotalValue = strat.calcTotalValue();
            strat.divest(prevTotalValue);
            underlying.safeTransfer(address(strat_), underlying.balanceOf(address(this)));
            strat_.invest();
            if(!force) {
                require(strat_.calcTotalValue() >= prevTotalValue);
                require(strat.calcTotalValue() == 0);
            }
        } else {
            require(msg.sender == owner());
            _unpause();
        }
        strat = strat_;

        emit StrategyChanged(address(strat));
    }

    // if limit == 0 then there is no deposit limit
    function setDepositLimit(uint limit) external onlyOwner {
        depositLimit = limit;

        emit DepositLimitUpdated(limit);
    }

    // Any tokens (other than the target) that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        require(_token != address(target));
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

    function harvest(uint amount) external onlyHarvester returns (uint afterFee) {
        require(amount <= underlyingYield(), "Amount larger than generated yield");
        strat.divest(amount);
        if(performanceFee > 0) {
            uint fee = amount.mul(performanceFee).div(MAX_FEE);
            afterFee = amount.sub(fee);
            underlying.safeTransfer(owner(), fee);
        } else {
            afterFee = amount;
        }
        underlying.safeTransfer(harvester, afterFee);
    }

    function distribute(uint amount) external onlyHarvester {
        distributeDividends(amount);
        lastDistribution = block.timestamp;
    }

}

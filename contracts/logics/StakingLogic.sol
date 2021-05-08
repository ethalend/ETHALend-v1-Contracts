//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRewards.sol";

/**
    Synthetix Rewards Contract interaction for Vault and LP tokens
 */
contract StakingLogic {


  function setApproval(
        IERC20 erc20,
        uint256 srcAmt,
        address to
    ) internal {
        uint256 tokenAllowance = erc20.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20.approve(to, uint(-1));
        }
    }
    /**
     * @notice Stake LP Tokens
     * @dev amount of tokens to stake (-1 = all balance)
     */
    function stake(IRewards rewards, IERC20 lpToken, uint256 amt) external {
        uint256 realAmt = amt == uint256(-1)
            ? lpToken.balanceOf(address(this))
            : amt;

        setApproval(lpToken, realAmt, address(rewards));

        rewards.stake(realAmt);
    }

    /**
     * @notice Unstake LP from Staking contract
     */
    function unstake(IRewards rewards, uint256 amount) external {
        rewards.withdraw(amount);
    }

    /**
     * @notice Claim ETHA Rewards
     */
    function claimRewards(IRewards rewards) external {
        rewards.getReward();
    }

    /**
     * @notice Unstake and claim All ETHA Rewards
     */
    function exit(IRewards rewards) external {
        rewards.exit();
    }
}

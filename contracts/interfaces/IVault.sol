//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Detailed is IERC20 {
    function decimals() external view returns (uint8);
}

interface IVault {
    function totalSupply() view external returns (uint);
    function harvest(uint amount) external returns (uint afterFee);
    function distribute(uint amount) external;
    function underlying() external view returns (IERC20Detailed);
    function target() external view returns (IERC20);
    function owner() external view returns (address);
    function timelock() external view returns (address payable);
    function claimOnBehalf(address recipient) external;
    function lastDistribution() view external returns (uint);
    function balanceOf(address) view external returns (uint);
     function underlyingYield() external returns (uint);

    function deposit(uint amount) external;
    function depositAndWait(uint amount) external;
    function withdraw(uint amount) external;
    function withdrawPending(uint amount) external;
    function claim() external;
    function unclaimedProfit(address user) external view returns (uint256);
    function pending(address user) external view returns (uint256);
}
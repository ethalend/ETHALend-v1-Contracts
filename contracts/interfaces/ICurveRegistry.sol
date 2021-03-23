//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

interface ICurveRegistry {
    function find_pool_for_coins(
        address _from,
        address _to,
        uint256 i
    ) external view returns (address);

    function get_exchange_amount(
        address _pool,
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (uint256);
}
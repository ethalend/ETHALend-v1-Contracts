//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

interface ICurveTwo {
    // solium-disable-next-line mixedcase
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;

    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount)
        external payable;

    function remove_liquidity_imbalance(
        uint256[2] calldata amounts,
        uint256 max_burn_amount
    ) external;

    function calc_withdraw_one_coin(uint256 _token_amount, int128 i)
        external
        view
        returns (uint256);
}
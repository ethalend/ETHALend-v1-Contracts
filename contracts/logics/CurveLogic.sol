//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IERC20.sol";
import "../interfaces/ICurve.sol";
import "../interfaces/ICurveTwo.sol";
import "../interfaces/ICurveRegistry.sol";

contract CurveLogic {
    // CURVE REGISTRY
    ICurveRegistry internal constant CURVE_REGISTRY = ICurveRegistry(
        0x7002B727Ef8F5571Cb5F9D70D13DBEEb4dFAe9d1
    );
    // CURVE POOLS
    ICurve internal constant CURVE_COMPOUND = ICurve(
        0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56
    );
    ICurve internal constant CURVE_USDT = ICurve(
        0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C
    );
    ICurve internal constant CURVE_Y = ICurve(
        0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51
    );
    ICurve internal constant CURVE_B = ICurve(
        0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27
    );
    ICurve internal constant CURVE_S = ICurve(
        0xA5407eAE9Ba41422680e2e00537571bcC53efBfD
    );
    ICurve internal constant CURVE_PAX = ICurve(
        0x06364f10B501e868329afBc005b3492902d6C763
    );

    // TOKENS
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant TUSD_ADDRESS = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address constant BUSD_ADDRESS = 0x4Fabb145d64652a948d72533023f6E7A623C7C53;
    address constant SUSD_ADDRESS = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address constant PAX_ADDRESS = 0x8E870D67F660D95d5be530380D0eC0bd388289E1;
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function getBestRate(
        address src,
        address dest,
        uint256 srcAmt,
        uint256 limit
    ) external view returns (address pool, uint256 destAmt) {
        for (uint256 i = 0; i <= limit; i++) {
            address checkPool = CURVE_REGISTRY.find_pool_for_coins(src, dest, i);
            uint256 result = CURVE_REGISTRY.get_exchange_amount(
                checkPool,
                src,
                dest,
                srcAmt
            );
            if (result > destAmt) {
                destAmt = result;
                pool = checkPool;
            }
        }
    }

    /**
     * @dev setting allowance to compound for the "user proxy" if required
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

    function swapOnCurveCompound(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {

        int128 i;
        int128 j;

        for(int128 x = 1; x <= 2; x++){
            if(CURVE_COMPOUND.underlying_coins(x) == src) i = x;
            if(CURVE_COMPOUND.underlying_coins(x) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_COMPOUND));

        CURVE_COMPOUND.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveUSDT(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 3; x++){
            if(CURVE_USDT.underlying_coins(x) == src) i = x;
            if(CURVE_USDT.underlying_coins(x) == dest) j = x;
        }
        
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_USDT));

        CURVE_USDT.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveY(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_Y.underlying_coins(x) == src) i = x;
            if(CURVE_Y.underlying_coins(x) == dest) j = x;
        }
        
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_Y));

        CURVE_Y.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveB(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_B.underlying_coins(x) == src) i = x;
            if(CURVE_B.underlying_coins(x) == dest) j = x;
        }
        
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_B));

        CURVE_B.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveSynth(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_S.underlying_coins(x) == src) i = x;
            if(CURVE_S.underlying_coins(x) == dest) j = x;
        }
        
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_S));

        CURVE_S.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurvePAX(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_PAX.underlying_coins(x) == src) i = x;
            if(CURVE_PAX.underlying_coins(x) == dest) j = x;
        }
        
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_PAX));

        CURVE_PAX.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    // TODO: Generic Function to Swap on any Pool

    /**
     * @notice add liquidity to Curve Pool
     */
    function addLiquidity(
        ICurveTwo curveToken,
        IERC20 underlying,
        uint256 amount,
        uint256 tokenId // 0 or 1
    ) external payable {
        uint256 realAmt = amount == uint256(-1)
            ? underlying.balanceOf(address(this))
            : amount;

        uint256[2] memory tokenAmts;
        tokenAmts[tokenId] = realAmt;

        uint value = amount;
        if(address(underlying) != ETH_ADDRESS) {
            value = 0;
            setApproval(address(underlying), amount, address(curveToken));
        }
        curveToken.add_liquidity{value:value}(tokenAmts, 0);
    }
    
}

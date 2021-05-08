//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface ICurve {
    // solium-disable-next-line mixedcase
    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;

    // solium-disable-next-line mixedcase
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;

    // solium-disable-next-line mixedcase
    function underlying_coins(
        int128 arg0
    ) external view returns(address);
}

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

interface IERC20 {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

import "hardhat/console.sol";

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

    // EVENTS
    event LogSwap(address indexed src, address indexed dest, uint amount);

    // TOKENS
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant TUSD_ADDRESS = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address constant BUSD_ADDRESS = 0x4Fabb145d64652a948d72533023f6E7A623C7C53;
    address constant SUSD_ADDRESS = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address constant PAX_ADDRESS = 0x8E870D67F660D95d5be530380D0eC0bd388289E1;

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
         if (srcAmt > IERC20(erc20).allowance(address(this), to)) {
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
            if(CURVE_COMPOUND.underlying_coins(x-1) == src) i = x;
            if(CURVE_COMPOUND.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_COMPOUND));

        CURVE_COMPOUND.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    function swapOnCurveUSDT(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 3; x++){
            if(CURVE_USDT.underlying_coins(x-1) == src) i = x;
            if(CURVE_USDT.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_USDT));

        CURVE_USDT.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    function swapOnCurveY(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_Y.underlying_coins(x-1) == src) i = x;
            if(CURVE_Y.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_Y));

        CURVE_Y.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    function swapOnCurveB(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_B.underlying_coins(x-1) == src) i = x;
            if(CURVE_B.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_B));

        CURVE_B.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    function swapOnCurveSynth(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_S.underlying_coins(x-1) == src) i = x;
            if(CURVE_S.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_S));

        CURVE_S.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    function swapOnCurvePAX(
        address src,
        address dest,
        uint256 srcAmt
    ) external returns (uint256) {
        int128 i;
        int128 j;

        for(int128 x = 1; x <= 4; x++){
            if(CURVE_PAX.underlying_coins(x-1) == src) i = x;
            if(CURVE_PAX.underlying_coins(x-1) == dest) j = x;
        }

        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(CURVE_PAX));

        CURVE_PAX.exchange_underlying(i - 1, j - 1, srcAmt, 0);

        emit LogSwap(src, dest, srcAmt);
    }

    // TODO: Generic Function to Swap on any Pool

}

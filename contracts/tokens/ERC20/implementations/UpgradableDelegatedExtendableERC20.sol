pragma solidity ^0.8.0;

import {ERC20CoreExtendableBase} from "../extensions/ERC20CoreExtendableBase.sol";
import {ERC20DelegateCore} from "../core/ERC20DelegateCore.sol";
import {ERC20DelegateProxy} from "../proxy/ERC20DelegateProxy.sol";
import {BaseERC20Storage} from "../storage/BaseERC20Storage.sol";
import {ERC20ExtendableLib} from "../extensions/ERC20ExtendableLib.sol";

contract UpgradableDelegatedExtendableERC20 is ERC20DelegateProxy {
    
    constructor(string memory name_, string memory symbol_, address core_implementation_) ERC20DelegateProxy() {
        BaseERC20Storage store = new BaseERC20Storage(name_, symbol_);
        ERC20DelegateCore implementation = ERC20DelegateCore(core_implementation_);

        //TODO Check interface exported by core_implementation_

        _setImplementation(address(implementation));
        _setStore(address(store));

        //Only we can modify the storage contract
        //(and the ERC20DelegateCore contract given when we run delegatecall)
        store.changeCurrentWriter(address(this));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }

    function registerExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20CoreExtendableBase.registerExtension.selector, extension))[0] == 0x01;
    }

    function removeExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20CoreExtendableBase.removeExtension.selector, extension))[0] == 0x01;
    }

    function disableExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20CoreExtendableBase.disableExtension.selector, extension))[0] == 0x01;
    }

    function enableExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20CoreExtendableBase.enableExtension.selector, extension))[0] == 0x01;
    }

    function allExtension() external view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's store here at the proxy
        //The ERC20ExtendableLib library offers functions to do this
        return ERC20ExtendableLib._allExtensions();
    }
}
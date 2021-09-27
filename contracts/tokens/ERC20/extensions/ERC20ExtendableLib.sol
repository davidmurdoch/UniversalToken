pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Extension} from "./IERC20Extension.sol";

/**
* @dev Verify if a token transfer can be executed or not, on the validator's perspective.
* @param token Token address that is executing this extension. If extensions are being called via delegatecall then address(this) == token
* @param payload The full payload of the initial transaction.
* @param partition Name of the partition (left empty for ERC20 transfer).
* @param operator Address which triggered the balance decrease (through transfer or redemption).
* @param from Token holder.
* @param to Token recipient for a transfer and 0x for a redemption.
* @param value Number of tokens the token holder balance is decreased by.
* @param data Extra information (if any).
* @param operatorData Extra information, attached by the operator (if any).
*/
struct TransferData {
    address token;
    bytes payload;
    bytes32 partition;
    address operator;
    address from;
    address to;
    uint value;
    bytes data;
    bytes operatorData;
}


library ERC20ExtendableLib {
    bytes32 constant ERC20_EXTENSION_LIST_LOCATION = keccak256("erc20.core.storage.address");
    uint8 constant EXTENSION_NOT_EXISTS = 0;
    uint8 constant EXTENSION_ENABLED = 1;
    uint8 constant EXTENSION_DISABLED = 2;

    struct ERC20ExtendableData {
        address[] registeredExtensions;
        mapping(address => uint8) extensionStateCache;
        mapping(address => uint256) extensionIndexes;
    }

    function extensionStorage() private pure returns (ERC20ExtendableData storage ds) {
        bytes32 position = ERC20_EXTENSION_LIST_LOCATION;
        assembly {
            ds.slot := position
        }
    }

    function _registerExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //First we need to verify this is a valid contract
        IERC165 ext165 = IERC165(extension);
        
        require(ext165.supportsInterface(0x01ffc9a7), "The extension must support IERC165");
        require(ext165.supportsInterface(type(IERC20Extension).interfaceId), "The extension must support IERC20Extension interface");

        //Interface has been validated, add it to storage
        extensionData.extensionIndexes[extension] = extensionData.registeredExtensions.length;
        extensionData.registeredExtensions.push(extension);
        extensionData.extensionStateCache[extension] = EXTENSION_ENABLED;
    }

    function _disableExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_ENABLED, "The extension must be enabled");

        extensionData.extensionStateCache[extension] = EXTENSION_DISABLED;
    }

    function _enableExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_DISABLED, "The extension must be enabled");

        extensionData.extensionStateCache[extension] = EXTENSION_ENABLED;
    }

    function _allExtensions() internal view returns (address[] memory) {
        ERC20ExtendableData storage extensionData = extensionStorage();
        return extensionData.registeredExtensions;
    }

    function _removeExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] != EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        // To prevent a gap in the extensions array, we store the last extension in the index of the extension to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastExtensionIndex = extensionData.registeredExtensions.length - 1;
        uint256 extensionIndex = extensionData.extensionIndexes[extension];

        // When the extension to delete is the last extension, the swap operation is unnecessary. However, since this occurs so
        // rarely that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement
        address lastExtension = extensionData.registeredExtensions[lastExtensionIndex];

        extensionData.registeredExtensions[extensionIndex] = lastExtension;
        extensionData.extensionIndexes[lastExtension] = extensionIndex;

        delete extensionData.extensionIndexes[extension];
        extensionData.registeredExtensions.pop();

        extensionData.extensionStateCache[extension] = EXTENSION_NOT_EXISTS;
    }

    function _validateTransfer(TransferData memory data) internal view returns (bool) {
        //Go through each extension, if it's enabled execute the validate function
        //If any extension returns false, halt and return false
        //If they all return true (or there are no extensions), then return true

        ERC20ExtendableData storage extensionData = extensionStorage();

        for (uint i = 0; i < extensionData.registeredExtensions.length; i++) {
            address extension = extensionData.registeredExtensions[i];

            if (extensionData.extensionStateCache[extension] == EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the validate function
            IERC20Extension ext = IERC20Extension(extension);

            if (!ext.validateTransfer(data)) {
                return false;
            }
        }

        return true;
    }

    function _executeAfterTransfer(TransferData memory data) internal returns (bool) {
        //Go through each extension, if it's enabled execute the onTransferExecuted function
        //If any extension returns false, halt and return false
        //If they all return true (or there are no extensions), then return true

        ERC20ExtendableData storage extensionData = extensionStorage();

        for (uint i = 0; i < extensionData.registeredExtensions.length; i++) {
            address extension = extensionData.registeredExtensions[i];

            if (extensionData.extensionStateCache[extension] == EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the validate function
            IERC20Extension ext = IERC20Extension(extension);

            if (!ext.onTransferExecuted(data)) {
                return false;
            }
        }

        return true;
    }
}
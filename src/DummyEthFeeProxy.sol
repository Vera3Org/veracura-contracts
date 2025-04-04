// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EthereumFeeProxy
 * @notice This contract performs an Ethereum transfer with a Fee sent to a third address and stores a reference
 */
contract EthereumFeeProxy is ReentrancyGuard {
    // Event to declare a transfer with a reference
    event TransferWithReferenceAndFee(
        address to, uint256 amount, bytes indexed paymentReference, uint256 feeAmount, address feeAddress
    );

    // Fallback function returns funds to the sender
    receive() external payable {
        revert("not payable receive");
    }

    /**
     * @notice Performs an Ethereum transfer with a reference
     * @param _to Transfer recipient
     * @param _paymentReference Reference of the payment related
     * @param _feeAmount The amount of the payment fee (part of the msg.value)
     * @param _feeAddress The fee recipient
     */
    function transferWithReferenceAndFee(
        address payable _to,
        bytes calldata _paymentReference,
        uint256 _feeAmount,
        address payable _feeAddress
    ) external payable {
        transferExactEthWithReferenceAndFee(_to, msg.value - _feeAmount, _paymentReference, _feeAmount, _feeAddress);
    }

    /**
     * @notice Performs an Ethereum transfer with a reference with an exact amount of eth
     * @param _to Transfer recipient
     * @param _amount Amount to transfer
     * @param _paymentReference Reference of the payment related
     * @param _feeAmount The amount of the payment fee (part of the msg.value)
     * @param _feeAddress The fee recipient
     */
    function transferExactEthWithReferenceAndFee(
        address payable _to,
        uint256 _amount,
        bytes calldata _paymentReference,
        uint256 _feeAmount,
        address payable _feeAddress
    ) public payable nonReentrant {
        (bool sendSuccess,) = _to.call{value: _amount}("");
        require(sendSuccess, "Could not pay the recipient");

        _feeAddress.transfer(_feeAmount);

        // transfer the remaining ethers to the sender
        (bool sendBackSuccess,) = payable(msg.sender).call{value: msg.value - _amount - _feeAmount}("");
        require(sendBackSuccess, "Could not send remaining funds to the payer");

        emit TransferWithReferenceAndFee(_to, _amount, _paymentReference, _feeAmount, _feeAddress);
    }
}

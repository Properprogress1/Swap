// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OrderBasedBookSwap is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Order {
        address maker;
        address tokenToSell;
        uint256 amountToSell;
        address tokenToBuy;
        uint256 amountToBuy;
        bool isActive;
        uint256 expirationTime; // Added expiration time for orders
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;

    event OrderCreated(uint256 indexed orderId, address indexed maker, address tokenToSell, uint256 amountToSell, address tokenToBuy, uint256 amountToBuy, uint256 expirationTime);
    event OrderFulfilled(uint256 indexed orderId, address indexed taker);
    event OrderCancelled(uint256 indexed orderId);

    function createOrder(
        address _tokenToSell,
        uint256 _amountToSell,
        address _tokenToBuy,
        uint256 _amountToBuy,
        uint256 _expirationTime // Expiration time in seconds
    ) external nonReentrant {
        require(_tokenToSell != address(0), "Invalid transaction");
        (_tokenToBuy != address(0), "Invalid token addresses");
        require(_amountToSell > 0, "Invalid amount");
        require(_amountToBuy > 0, "Invalid amount");
        require(_expirationTime > block.timestamp, "Expiration time must be in the future");

        IERC20(_tokenToSell).safeTransferFrom(msg.sender, address(this), _amountToSell);

        orders[nextOrderId] = Order({
            maker: msg.sender,
            tokenToSell: _tokenToSell,
            amountToSell: _amountToSell,
            tokenToBuy: _tokenToBuy,
            amountToBuy: _amountToBuy,
            isActive: true,
            expirationTime: _expirationTime
        });

        emit OrderCreated(nextOrderId, msg.sender, _tokenToSell, _amountToSell, _tokenToBuy, _amountToBuy, _expirationTime);
        nextOrderId++;
    }

    function fulfillOrder(uint256 _orderId) external nonReentrant {
        Order storage order = orders[_orderId];
        require(order.isActive, "Order is not active");
        require(block.timestamp <= order.expirationTime, "Order has expired");

        IERC20(order.tokenToBuy).safeTransferFrom(msg.sender, order.maker, order.amountToBuy);
        IERC20(order.tokenToSell).safeTransfer(msg.sender, order.amountToSell);

        order.isActive = false;
        emit OrderFulfilled(_orderId, msg.sender);
    }

    function cancelOrder(uint256 _orderId) external nonReentrant {
        Order storage order = orders[_orderId];
        require(order.isActive, "Order is not active");
        require(order.maker == msg.sender, "Not the order creator");

        IERC20(order.tokenToSell).safeTransfer(msg.sender, order.amountToSell);

        order.isActive = false;
        emit OrderCancelled(_orderId);
    }

    function getActiveOrders() external view returns (Order[] memory) {
        uint256 activeOrdersCount = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive && block.timestamp <= orders[i].expirationTime) {
                activeOrdersCount++;
            }
        }

        Order[] memory activeOrders = new Order[](activeOrdersCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive && block.timestamp <= orders[i].expirationTime) {
                activeOrders[currentIndex] = orders[i];
                currentIndex++;
            }
        }

        return activeOrders;
    }
}

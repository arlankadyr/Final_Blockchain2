// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    uint256 private requestIdCounter;

    mapping(uint256 => address) public requestToConsumer;

    event RandomWordsRequested(uint256 requestId, address consumer);

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external returns (uint256 requestId) {
        requestId = ++requestIdCounter;
        requestToConsumer[requestId] = msg.sender;
        emit RandomWordsRequested(requestId, msg.sender);
    }

    /// @notice Симулируем ответ Chainlink — вызываем из теста
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        address consumer = requestToConsumer[requestId];
        require(consumer != address(0), "Unknown requestId");
        VRFConsumerBaseV2(consumer).rawFulfillRandomWords(requestId, randomWords);
    }

    /// @notice Удобный хелпер — fulfil с одним числом
    function fulfillRandomWordsWithOverride(
        uint256 requestId,
        uint256 randomWord
    ) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        this.fulfillRandomWords(requestId, words);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Challenge.sol";
import "./ActivityRegistry.sol";

/// @title Activity Factory - 活动创建工厂
/// @notice 支持创建押金挑战活动，并自动注册到ActivityRegistry
contract ActivityFactory {
    ActivityRegistry public immutable activityRegistry;
    
    // 维护所有创建的活动地址列表
    address[] public activities;

    event DepositChallengeCreated(
        address indexed challengeAddress,
        address indexed creator,
        uint256 indexed activityId,
        string title
    );

    constructor(address _activityRegistry) {
        require(_activityRegistry != address(0), "INVALID_REGISTRY");
        activityRegistry = ActivityRegistry(_activityRegistry);
    }

    /// @notice 创建押金挑战活动（押金奖池模式）
    /// @param _title 活动标题
    /// @param _description 活动描述
    /// @param _depositAmount 押金金额（必须 > 0）
    /// @param _totalRounds 总轮次数
    /// @param _maxParticipants 最大参与人数
    /// @param _isPublic 是否公开
    /// @param _creatorName 活动创建者名称
    function createDepositChallenge(
        string memory _title,
        string memory _description,
        uint256 _depositAmount,
        uint256 _totalRounds,
        uint256 _maxParticipants,
        bool _isPublic,
        string memory _creatorName
    ) external returns (address challengeAddress, uint256 activityId) {
        require(_depositAmount > 0, "DEPOSIT_AMOUNT_MUST_BE_GREATER_THAN_ZERO");
        require(_totalRounds > 0, "TOTAL_ROUNDS_MUST_BE_GREATER_THAN_ZERO");
        require(_maxParticipants > 0, "MAX_PARTICIPANTS_MUST_BE_GREATER_THAN_ZERO");
        
        uint256 startTime = 0; // 未开始，需要手动开始
        Challenge newChallenge = new Challenge(
            _title,
            _description,
            msg.sender,
            _depositAmount,
            _totalRounds,
            _maxParticipants,
            startTime
        );

        challengeAddress = address(newChallenge);
        activities.push(challengeAddress);

        activityId = activityRegistry.registerActivity(
            challengeAddress,
            _title,
            _description,
            _isPublic,
            0,  // incentiveType: 0 = 押金池
            msg.sender,  // 传递真实的用户地址作为 creator
            _creatorName  // 传递创建者名称
        );

        emit DepositChallengeCreated(challengeAddress, msg.sender, activityId, _title);
        return (challengeAddress, activityId);
    }

    /// @notice 获取所有通过此工厂创建的活动地址
    /// @return 所有活动合约地址数组
    function getAllActivities() external view returns (address[] memory) {
        return activities;
    }
    
    /// @notice 获取活动总数
    /// @return 创建的活动数量
    function activityCount() external view returns (uint256) {
        return activities.length;
    }
}


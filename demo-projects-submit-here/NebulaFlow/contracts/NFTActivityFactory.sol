// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NFTActivity.sol";
import "./ActivityRegistry.sol";

/// @title NFT Activity Factory - NFT活动创建工厂
/// @notice 支持创建NFT活动，并自动注册到ActivityRegistry
/// @notice 与 ActivityFactory.sol 完全独立，不共享任何代码
contract NFTActivityFactory {
    ActivityRegistry public immutable activityRegistry;
    
    // 维护所有创建的NFT活动地址列表
    address[] public nftActivities;

    event NFTActivityCreated(
        address indexed activityAddress,
        address indexed creator,
        uint256 indexed activityId,
        string title
    );

    constructor(address _activityRegistry) {
        require(_activityRegistry != address(0), "INVALID_REGISTRY");
        activityRegistry = ActivityRegistry(_activityRegistry);
    }

    /// @notice 创建NFT活动（NFT奖池模式）
    /// @param _title 活动标题
    /// @param _description 活动描述
    /// @param _totalRounds 总轮次数
    /// @param _maxParticipants 最大参与人数
    /// @param _isPublic 是否公开
    /// @param _creatorName 活动创建者名称
    function createNFTActivity(
        string memory _title,
        string memory _description,
        uint256 _totalRounds,
        uint256 _maxParticipants,
        bool _isPublic,
        string memory _creatorName
    ) external returns (address activityAddress, uint256 activityId) {
        require(_totalRounds > 0, "TOTAL_ROUNDS_MUST_BE_GREATER_THAN_ZERO");
        require(_maxParticipants > 0, "MAX_PARTICIPANTS_MUST_BE_GREATER_THAN_ZERO");
        
        uint256 startTime = 0; // 未开始，需要手动开始
        NFTActivity newActivity = new NFTActivity(
            _title,
            _description,
            msg.sender,
            _totalRounds,
            _maxParticipants,
            startTime
        );

        activityAddress = address(newActivity);
        nftActivities.push(activityAddress);

        activityId = activityRegistry.registerActivity(
            activityAddress,
            _title,
            _description,
            _isPublic,
            1,  // incentiveType: 1 = NFT奖池
            msg.sender,  // 传递真实的用户地址作为 creator
            _creatorName  // 传递创建者名称
        );

        emit NFTActivityCreated(activityAddress, msg.sender, activityId, _title);
        return (activityAddress, activityId);
    }

    /// @notice 获取所有通过此工厂创建的NFT活动地址
    /// @return 所有NFT活动合约地址数组
    function getAllNFTActivities() external view returns (address[] memory) {
        return nftActivities;
    }
    
    /// @notice 获取NFT活动总数
    /// @return 创建的NFT活动数量
    function nftActivityCount() external view returns (uint256) {
        return nftActivities.length;
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Activity Registry - 管理活动
/// @notice 存储活动的元数据
contract ActivityRegistry {
    struct ActivityMetadata {
        address activityContract;  // Challenge 合约地址
        address creator;
        string creatorName;  // 活动创建者名称（用于显示，替换地址）
        string title;
        string description;
        uint256 createdAt;
        bool isPublic;  // 是否公开显示
        uint8 incentiveType;  // 激励类型：0=押金池，可扩展其他类型
    }

    // activityId => ActivityMetadata
    mapping(uint256 => ActivityMetadata) public activities;
    uint256 public activityCount;

    // user => activityIds[] (用户参与的所有活动)
    mapping(address => uint256[]) public userActivities;

    // activityContract => activityId
    mapping(address => uint256) public contractToActivity;

    event ActivityRegistered(
        uint256 indexed activityId,
        address indexed creator,
        address activityContract,
        string title
    );


    /// @notice 注册新活动
    /// @param _activityContract 活动合约地址
    /// @param _title 活动标题
    /// @param _description 活动描述
    /// @param _isPublic 是否公开
    /// @param _incentiveType 激励类型 (0=押金池，可扩展其他类型)
    /// @param _creator 活动创建者地址（可选，如果不提供则使用 msg.sender）
    /// @param _creatorName 活动创建者名称（用于显示，替换地址）
    function registerActivity(
        address _activityContract,
        string memory _title,
        string memory _description,
        bool _isPublic,
        uint8 _incentiveType,
        address _creator,
        string memory _creatorName
    ) external returns (uint256) {
        require(_activityContract != address(0), "INVALID_CONTRACT");
        require(bytes(_title).length > 0, "TITLE_REQUIRED");
        require(bytes(_creatorName).length > 0, "CREATOR_NAME_REQUIRED");
        // incentiveType 验证已移除，允许扩展新的激励类型
        
        // 如果提供了 _creator，使用它；否则使用 msg.sender
        address creator = _creator != address(0) ? _creator : msg.sender;

        uint256 activityId = ++activityCount; // 从 1 开始，避免 activityId = 0
        activities[activityId] = ActivityMetadata({
            activityContract: _activityContract,
            creator: creator,
            creatorName: _creatorName,
            title: _title,
            description: _description,
            createdAt: block.timestamp,
            isPublic: _isPublic,
            incentiveType: _incentiveType
        });

        contractToActivity[_activityContract] = activityId;

        emit ActivityRegistered(
            activityId,
            creator,
            _activityContract,
            _title
        );

        return activityId;
    }

    /// @notice 获取用户的所有活动ID
    function getUserActivities(address _user) external view returns (uint256[] memory) {
        return userActivities[_user];
    }

    /// @notice 获取活动元数据
    function getActivityMetadata(uint256 _activityId) external view returns (ActivityMetadata memory) {
        return activities[_activityId];
    }

    /// @notice 获取活动元数据（返回多个值，避免 struct 解析问题）
    /// @param _activityId 活动ID
    /// @return activityContract 活动合约地址
    /// @return creator 创建者地址
    /// @return creatorName 创建者名称
    /// @return title 活动标题
    /// @return description 活动描述
    /// @return createdAt 创建时间戳
    /// @return isPublic 是否公开
    /// @return incentiveType 激励类型 (0=押金池，可扩展其他类型)
    function getActivityMetadataTuple(uint256 _activityId) external view returns (
        address activityContract,
        address creator,
        string memory creatorName,
        string memory title,
        string memory description,
        uint256 createdAt,
        bool isPublic,
        uint8 incentiveType
    ) {
        ActivityMetadata memory metadata = activities[_activityId];
        return (
            metadata.activityContract,
            metadata.creator,
            metadata.creatorName,
            metadata.title,
            metadata.description,
            metadata.createdAt,
            metadata.isPublic,
            metadata.incentiveType
        );
    }

}


// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BaseDelegator} from "./BaseDelegator.sol";

import {IFullRestakeDelegator} from "src/interfaces/delegator/IFullRestakeDelegator.sol";
import {IBaseDelegator} from "src/interfaces/delegator/IBaseDelegator.sol";
import {IVault} from "src/interfaces/vault/IVault.sol";

import {Checkpoints} from "src/contracts/libraries/Checkpoints.sol";

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract FullRestakeDelegator is BaseDelegator, IFullRestakeDelegator {
    using Checkpoints for Checkpoints.Trace256;
    using Math for uint256;

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    bytes32 public constant NETWORK_LIMIT_SET_ROLE = keccak256("NETWORK_LIMIT_SET_ROLE");

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    bytes32 public constant OPERATOR_NETWORK_LIMIT_SET_ROLE = keccak256("OPERATOR_NETWORK_LIMIT_SET_ROLE");

    mapping(address network => Checkpoints.Trace256 value) private _networkLimit;

    mapping(address network => mapping(address operator => Checkpoints.Trace256 value)) private _operatorNetworkLimit;

    constructor(
        address networkRegistry,
        address vaultFactory,
        address operatorVaultOptInService,
        address operatorNetworkOptInService,
        address delegatorFactory,
        uint64 entityType
    )
        BaseDelegator(
            networkRegistry,
            vaultFactory,
            operatorVaultOptInService,
            operatorNetworkOptInService,
            delegatorFactory,
            entityType
        )
    {}

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function networkLimitAt(address network, uint48 timestamp) public view returns (uint256) {
        return _networkLimit[network].upperLookupRecent(timestamp);
    }

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function networkLimit(address network) public view returns (uint256) {
        return _networkLimit[network].latest();
    }

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function operatorNetworkLimitAt(
        address network,
        address operator,
        uint48 timestamp
    ) public view returns (uint256) {
        return _operatorNetworkLimit[network][operator].upperLookupRecent(timestamp);
    }

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function operatorNetworkLimit(address network, address operator) public view returns (uint256) {
        return _operatorNetworkLimit[network][operator].latest();
    }

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function setNetworkLimit(address network, uint256 amount) external onlyRole(NETWORK_LIMIT_SET_ROLE) {
        if (amount > maxNetworkLimit[network]) {
            revert ExceedsMaxNetworkLimit();
        }

        _setNetworkLimit(network, amount);

        emit SetNetworkLimit(network, amount);
    }

    /**
     * @inheritdoc IFullRestakeDelegator
     */
    function setOperatorNetworkLimit(
        address network,
        address operator,
        uint256 amount
    ) external onlyRole(OPERATOR_NETWORK_LIMIT_SET_ROLE) {
        _setOperatorNetworkLimit(network, operator, amount);

        emit SetOperatorNetworkLimit(network, operator, amount);
    }

    function _setNetworkLimit(address network, uint256 amount) internal {
        _networkLimit[network].push(Time.timestamp(), amount);
    }

    function _setOperatorNetworkLimit(address network, address operator, uint256 amount) internal {
        _operatorNetworkLimit[network][operator].push(Time.timestamp(), amount);
    }

    function _stakeAtHints(
        address network,
        address operator,
        uint48 timestamp,
        StakeBaseHints memory baseHints
    ) internal view override returns (bytes memory) {
        (,,, uint32 activeStakeHint) = IVault(vault).activeStakeCheckpointAt(timestamp);
        (,,, uint32 networkLimitHint) = _networkLimit[network].upperLookupRecentCheckpoint(timestamp);
        (,,, uint32 operatorNetworkLimitHint) =
            _operatorNetworkLimit[network][operator].upperLookupRecentCheckpoint(timestamp);

        return abi.encode(
            StakeHints({
                baseHints: baseHints,
                activeStakeHint: activeStakeHint,
                networkLimitHint: networkLimitHint,
                operatorNetworkLimitHint: operatorNetworkLimitHint
            })
        );
    }

    function _stakeAt(
        address network,
        address operator,
        uint48 timestamp,
        bytes memory hints
    ) internal view override returns (uint256, IBaseDelegator.StakeBaseHints memory) {
        IFullRestakeDelegator.StakeHints memory hints_ = abi.decode(hints, (IFullRestakeDelegator.StakeHints));
        return (
            Math.min(
                IVault(vault).activeStakeAt(timestamp, hints_.activeStakeHint),
                Math.min(
                    _networkLimit[network].upperLookupRecent(timestamp, hints_.networkLimitHint),
                    _operatorNetworkLimit[network][operator].upperLookupRecent(
                        timestamp, hints_.operatorNetworkLimitHint
                    )
                )
            ),
            hints_.baseHints
        );
    }

    function _stakeAt(address network, address operator, uint48 timestamp) internal view override returns (uint256) {
        return Math.min(
            IVault(vault).activeStakeAt(timestamp),
            Math.min(networkLimitAt(network, timestamp), operatorNetworkLimitAt(network, operator, timestamp))
        );
    }

    function _stake(address network, address operator) internal view override returns (uint256) {
        return Math.min(
            IVault(vault).activeStake(), Math.min(networkLimit(network), operatorNetworkLimit(network, operator))
        );
    }

    function _setMaxNetworkLimit(uint256 amount) internal override {
        (bool exists,, uint256 latestValue) = _networkLimit[msg.sender].latestCheckpoint();
        if (exists) {
            _networkLimit[msg.sender].push(Time.timestamp(), Math.min(latestValue, amount));
        }
    }

    function _initializeInternal(
        address,
        bytes memory data
    ) internal override returns (IBaseDelegator.BaseParams memory) {
        InitParams memory params = abi.decode(data, (InitParams));

        if (
            params.baseParams.defaultAdminRoleHolder == address(0)
                && (params.networkLimitSetRoleHolders.length == 0 || params.operatorNetworkLimitSetRoleHolders.length == 0)
        ) {
            revert MissingRoleHolders();
        }

        for (uint256 i; i < params.networkLimitSetRoleHolders.length; ++i) {
            if (params.networkLimitSetRoleHolders[i] == address(0)) {
                revert ZeroAddressRoleHolder();
            }

            if (hasRole(NETWORK_LIMIT_SET_ROLE, params.networkLimitSetRoleHolders[i])) {
                revert DuplicateRoleHolder();
            }

            _grantRole(NETWORK_LIMIT_SET_ROLE, params.networkLimitSetRoleHolders[i]);
        }

        for (uint256 i; i < params.operatorNetworkLimitSetRoleHolders.length; ++i) {
            if (params.operatorNetworkLimitSetRoleHolders[i] == address(0)) {
                revert ZeroAddressRoleHolder();
            }

            if (hasRole(OPERATOR_NETWORK_LIMIT_SET_ROLE, params.operatorNetworkLimitSetRoleHolders[i])) {
                revert DuplicateRoleHolder();
            }

            _grantRole(OPERATOR_NETWORK_LIMIT_SET_ROLE, params.operatorNetworkLimitSetRoleHolders[i]);
        }

        return params.baseParams;
    }
}

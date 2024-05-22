// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IMigratableEntity} from "src/interfaces/base/IMigratableEntity.sol";

interface IVaultStorage is IMigratableEntity {
    error InvalidEpochDuration();
    error InvalidSlashDuration();
    error InvalidAdminFee();

    /**
     * @notice Initial parameters needed for a vault deployment.
     * @param owner owner of the vault (can set metadata and enable/disable deposit whitelist)
     * @param metadataURL URL with metadata of the vault
     * The metadata should contain: name, description, external_url, image.
     * @param collateral underlying vault collateral
     * @param epochDuration duration of an vault epoch
     * @param vetoDuration duration of the veto period for a slash request
     * @param slashDuration duration of the slash period for a slash request (after veto period)
     * @param adminFee admin fee (up to ADMIN_FEE_BASE inclusively)
     * @param depositWhitelist enable/disable deposit whitelist
     */
    struct InitParams {
        address owner;
        string metadataURL;
        address collateral;
        uint48 epochDuration;
        uint48 vetoDuration;
        uint48 slashDuration;
        uint256 adminFee;
        bool depositWhitelist;
    }

    /**
     * @notice Structure for a slashing limit.
     * @param amount amount of the collateral that can be slashed
     */
    struct Limit {
        uint256 amount;
    }

    /**
     * @notice Structure for a slashing limit which will be set in the future.
     * @param amount amount of the collateral that can be slashed
     * @param timestamp timestamp when the limit will be set
     */
    struct DelayedLimit {
        uint256 amount;
        uint48 timestamp;
    }

    /**
     * @notice Structure for a slash request.
     * @param network network which requested the slash
     * @param resolver resolver who can veto the slash
     * @param operator operator who could be slashed
     * @param amount maximum amount of the collateral to be slashed
     * @param vetoDeadline deadline for the resolver to veto the slash
     * @param slashDeadline deadline to execute slash
     * @param completed if the slash was vetoed/executed
     *
     */
    struct SlashRequest {
        address network;
        address resolver;
        address operator;
        uint256 amount;
        uint48 vetoDeadline;
        uint48 slashDeadline;
        bool completed;
    }

    /**
     * @notice Structure for a reward distribution.
     * @param network network on behalf of which the reward is distributed
     * @param amount amount of tokens to be distributed (admin fee is excluded)
     * @param timestamp time point stakes must taken into account at
     * @param creation timestamp when the reward distribution was created
     */
    struct RewardDistribution {
        address network;
        uint256 amount;
        uint48 timestamp;
        uint48 creation;
    }

    /**
     * @notice Get the maximum admin fee (= 100%).
     * @return maximum admin fee
     */
    function ADMIN_FEE_BASE() external view returns (uint256);

    /**
     * @notice Get the network limit setter's role.
     */
    function NETWORK_LIMIT_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the operator limit setter's role.
     */
    function OPERATOR_LIMIT_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the admin fee setter's role.
     */
    function ADMIN_FEE_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the deposit whitelist enabler/disabler's role.
     */
    function DEPOSIT_WHITELIST_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the depositor whitelist status setter's role.
     */
    function DEPOSITOR_WHITELIST_ROLE() external view returns (bytes32);

    /**
     * @notice Get the network registry's address.
     * @return address of the registry
     */
    function NETWORK_REGISTRY() external view returns (address);

    /**
     * @notice Get the operator registry's address.
     * @return address of the operator registry
     */
    function OPERATOR_REGISTRY() external view returns (address);

    /**
     * @notice Get the network middleware plugin's address.
     * @return address of the network middleware plugin
     */
    function NETWORK_MIDDLEWARE_PLUGIN() external view returns (address);

    /**
     * @notice Get the network opt-in plugin's address.
     * @return address of the network opt-in plugin
     */
    function NETWORK_OPT_IN_PLUGIN() external view returns (address);

    /**
     * @notice Get a vault collateral.
     * @return collateral underlying vault
     */
    function collateral() external view returns (address);

    /**
     * @notice Get a time point of the epoch duration set.
     * @return time point of the epoch duration set
     */
    function epochDurationInit() external view returns (uint48);

    /**
     * @notice Get a duration of the vault epoch.
     * @return duration of the epoch
     */
    function epochDuration() external view returns (uint48);

    /**
     * @notice Get a duration during which resolvers can veto slash requests.
     * @return duration of the veto period
     */
    function vetoDuration() external view returns (uint48);

    /**
     * @notice Get a duration during which slash requests can be executed (after veto period).
     * @return duration of the slash period
     */
    function slashDuration() external view returns (uint48);

    /**
     * @notice Get a URL with a vault's metadata.
     * The metadata should contain: name, description, external_url, image.
     * @return metadata URL of the vault
     */
    function metadataURL() external view returns (string memory);

    /**
     * @notice Get an admin fee.
     * @return admin fee
     */
    function adminFee() external view returns (uint256);

    /**
     * @notice Get a claimable fee amount for a particular token.
     * @param token address of the token
     * @return claimable fee
     */
    function claimableAdminFee(address token) external view returns (uint256);

    /**
     * @notice Get if the deposit whitelist is enabled.
     * @return if the deposit whitelist is enabled
     */
    function depositWhitelist() external view returns (bool);

    /**
     * @notice Get if a given account is whitelisted as a depositor.
     * @param account address to check
     * @return if the account is whitelisted as a depositor
     */
    function isDepositorWhitelisted(address account) external view returns (bool);

    /**
     * @notice Get a total amount of the withdrawals at a given epoch.
     * @param epoch epoch to get the total amount of the withdrawals at
     * @return total amount of the withdrawals at the epoch
     */
    function withdrawals(uint256 epoch) external view returns (uint256);

    /**
     * @notice Get a total amount of the withdrawals shares at a given epoch.
     * @param epoch epoch to get the total amount of the withdrawals shares at
     * @return total amount of the withdrawals shares at the epoch
     */
    function withdrawalsShares(uint256 epoch) external view returns (uint256);

    /**
     * @notice Get an amount of the withdrawals shares for a particular account at a given epoch.
     * @param epoch epoch to get the amount of the withdrawals shares for the account at
     * @param account account to get the amount of the withdrawals shares for
     * @return amount of the withdrawals shares for the account at the epoch
     */
    function withdrawalsSharesOf(uint256 epoch, address account) external view returns (uint256);

    /**
     * @notice Get a timestamp when the first deposit was made by a particular account.
     * @param account account to get the timestamp when the first deposit was made for
     * @return timestamp when the first deposit was made
     */
    function firstDepositAt(address account) external view returns (uint48);

    /**
     * @notice Get a slash request.
     * @param slashIndex index of the slash request
     * @return network network which requested the slash
     * @return resolver resolver who can veto the slash
     * @return operator operator who could be slashed
     * @return amount maximum amount of the collateral to be slashed
     * @return vetoDeadline deadline for the resolver to veto the slash
     * @return slashDeadline deadline to execute slash
     * @return completed if the slash was vetoed/executed
     */
    function slashRequests(uint256 slashIndex)
        external
        view
        returns (
            address network,
            address resolver,
            address operator,
            uint256 amount,
            uint48 vetoDeadline,
            uint48 slashDeadline,
            bool completed
        );

    /**
     * @notice Get a reward distribution.
     * @param token address of the token
     * @param rewardIndex index of the reward distribution
     * @return network network on behalf of which the reward is distributed
     * @return amount amount of tokens to be distributed
     * @return timestamp time point stakes must taken into account at
     * @return creation timestamp when the reward distribution was created
     */
    function rewards(
        address token,
        uint256 rewardIndex
    ) external view returns (address network, uint256 amount, uint48 timestamp, uint48 creation);

    /**
     * @notice Get a first index of the unclaimed rewards using a particular token by a given account.
     * @param account address of the account
     * @param token address of the token
     * @return first index of the unclaimed rewards
     */
    function lastUnclaimedReward(address account, address token) external view returns (uint256);

    /**
     * @notice Get a timestamp of last operator opt-out.
     * @param operator address of the operator
     * @return timestamp of the last operator opt-out
     */
    function operatorOptOutAt(address operator) external view returns (uint48);

    /**
     * @notice Get a maximum network limit for a particular network and resolver.
     * @param network address of the network
     * @param resolver address of the resolver
     * @return maximum network limit
     */
    function maxNetworkLimit(address network, address resolver) external view returns (uint256);

    /**
     * @notice Get next network limit for a particular network and resolver.
     * @param network address of the network
     * @param resolver address of the resolver
     * @return next network limit
     * @return timestamp when the limit will be set
     */
    function nextNetworkLimit(address network, address resolver) external view returns (uint256, uint48);

    /**
     * @notice Get next operator limit for a particular operator and network.
     * @param operator address of the operator
     * @param network address of the network
     * @return next operator limit
     * @return timestamp when the limit will be set
     */
    function nextOperatorLimit(address operator, address network) external view returns (uint256, uint48);
}
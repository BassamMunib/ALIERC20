// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "openzeppelin-contracts-3/utils/EnumerableSet.sol";
import "openzeppelin-contracts-3/utils/Address.sol";
import "./GSNRecipient.sol";

/**
 * @title Artificial Liquid Intelligence ERC20 Token
 *       (Alethea, Alethea Token, ALI)
 *       Version 1
 *
 * @notice ALI is the native utility token of the Alethea AI Protocol.
 *
 * @dev Standard burnable, non-mintable Zeppelin-based implementation: Version 1
 *
 * @author Basil Gorin
 */
contract AliERC20v1 is GSNRecipient {
	/**
	 * @dev Creates/deploys an ALI token ERC20 instance
	 */
	constructor() ERC20("Alethea Token", "ALI") {
		// mint 10 billion initial token supply to the deployer
		_mint(msg.sender, 10_000_000_000 ether); // we use "ether" suffix instead of "e18"
	}

    // ACCESS CONTROL
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;
    struct RoleData {
        EnumerableSet.AddressSet members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account);
    }
    function isSenderInRole(bytes32 role) public view returns(bool) {
		// delegate call to `isOperatorInRole`, passing transaction sender
		return hasRole(role, _msgSender());
	}
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return _roles[role].members.at(index);
    }
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }
    function grantRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to grant");
        _grantRole(role, account);
    }
    function addFeature(bytes32 feature) public {
		// delegate to Zeppelin's `grantRole`
		grantRole(feature, address(this));
	}
    function revokeRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to revoke");

        _revokeRole(role, account);
    }
    function renounceRole(bytes32 role, address account) public virtual {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, _roles[role].adminRole, adminRole);
        _roles[role].adminRole = adminRole;
    }
    function _grantRole(bytes32 role, address account) private {
        if (_roles[role].members.add(account)) {
            emit RoleGranted(role, account, _msgSender());
        }
    }
    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members.remove(account)) {
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    function isFeatureEnabled(bytes32 feature) public view returns(bool) {
		// delegate to Zeppelin's `hasRole`
		return hasRole(feature, address(this));
	}
    function removeFeature(bytes32 feature) public {
		// delegate to Zeppelin's `revokeRole`
		revokeRole(feature, address(this));
	}

	/**
	 * @inheritdoc IERC165
	 */
	function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
		// reconstruct from current interface and super interface
		return interfaceId == type(IERC20).interfaceId
			|| interfaceId == type(IERC20Metadata).interfaceId
			|| super.supportsInterface(interfaceId);
	}

	/**
	 * @notice Destroys some tokens from transaction sender account,
	 *      reducing the total supply.
	 *
	 * @dev Emits a {Transfer} event with `to` set to the zero address.
	 * @dev Throws if transaction sender doesn't have at least `amount` tokens.
	 *
	 * @param amount amount of tokens to burn
	 */
	function burn(uint256 amount) public {
		// delegate to super `_burn`
		_burn(_msgSender(), amount);
	}




    	// Role
	bytes32 constant ROLE_WHITELIST_OPERATOR = keccak256("Whitelist Operator");
	// Feature
	bytes32 constant FEATURE_ENABLE_TRANSFER = keccak256("Enable Transfer");

	mapping (address => bool) private _whiteList;
	address private _admin;

	function grantRoleWhitelistOperator(address _to) public {
		require(_msgSender() == _admin, "You are not allowed to grant whitelist operator");
        grantRole(ROLE_WHITELIST_OPERATOR, _to);
    }
    
    function revokeRoleWhitelistOperator(address _to) public {
		require(_msgSender() == _admin, "You are not allowed to revoke whitelist operator");
        revokeRole(ROLE_WHITELIST_OPERATOR, _to);
    }

	function addtowhitelist(address _toAdd) public {
		require(_msgSender() == _admin, "You are not allowed to add to whitelist");
		_whiteList[_toAdd] = true;
	}

	function enableWhitelist(bool _choice) public {
		require(isSenderInRole(ROLE_WHITELIST_OPERATOR), "You are not Whitelist operator");
		if(_choice)
			addFeature(FEATURE_ENABLE_TRANSFER);
		else
			removeFeature(FEATURE_ENABLE_TRANSFER);
	}

	function acceptRelayedCall(
        address relay,
        address from,
        bytes calldata encodedFunction,
        uint256 transactionFee,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes calldata approvalData,
        uint256 maxPossibleCharge
    ) external view override returns (uint256, bytes memory) {

		if(isFeatureEnabled(FEATURE_ENABLE_TRANSFER) && _whiteList[_msgSender()])
			return _approveRelayedCall();
        else			// error code
			_rejectRelayedCall(100);
    }

    // We won't do any pre or post processing, so leave _preRelayedCall and _postRelayedCall empty
    function _preRelayedCall(bytes memory context) internal override returns (bytes32) {    }

    function _postRelayedCall(bytes memory context, bool, uint256 actualCharge, bytes32) internal override {    }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./AiPodERC721v1.sol";
import "./IntelligentNFTv1.sol";

/**
 * @title Intelligent Token Linker (iNFT Linker)
 *
 * @notice iNFT Linker is a helper smart contract responsible for managing iNFTs.
 *      It creates and destroys iNFTs, determines iNFT creation price and destruction fee.
 *
 * @author Basil Gorin
 */
contract IntelliLinker is AccessExtension {
	/**
	 * @dev iNFT Linker mints/burns iNFTs defined by `iNftContract`
	 */
	// TODO: verify if we need this to be upgradeable
	address public immutable iNftContract;

	/**
	 * @dev iNFT Linker locks/unlocks AI Pod defined by `podContract` to mint/burn iNFT
	 */
	// TODO: verify if we need this to be upgradeable
	address public immutable podContract;

	/**
	 * @dev iNFT Linker locks/unlocks ALI tokens defined by `aliContract` to mint/burn iNFT
	 */
	// TODO: verify if we need this to be upgradeable
	address public immutable aliContract;

	/**
	 * @dev How much ALI token is locked into iNFT upon iNFT creation
	 */
	// TODO: add a mechanism to update it
	uint96 public linkPrice = 2_000 ether; // we use "ether" suffix instead of "e18"

	/**
	 * @dev How much ALI token is taken out as a fee (not sent back to iNFT owner)
	 *      on iNFT destruction
	 */
	// TODO: decide if it is an absolute value (like 200 ALI) or fraction (like 10%)
	uint96 public unlinkFee = 200 ether; // we use "ether" suffix instead of "e18"

	/**
	 * @dev NFT Contracts allowed iNFT to be linked to
	 */
	// TODO: add a mechanism to update it
	mapping(address => bool) whitelistedNftContracts;

	// TODO: similarly, add blacklistedNftContracts mapping

	/**
	 * @notice Token creator is responsible for creating (minting)
	 *      tokens to an arbitrary address
	 * @dev Feature FEATURE_ALLOW_ANY_NFT_CONTRACT allows minting tokens
	 *      (calling `mint` function)
	 */
	bytes32 public constant FEATURE_ALLOW_ANY_NFT_CONTRACT = keccak256("FEATURE_ALLOW_ANY_NFT_CONTRACT");

	/**
	 * @dev Fired in link() when new iNFT is created
	 *
	 * @param _by an address which executed the link function
	 * @param iNftId ID of the iNFT minted
	 * @param payer and address which funded the creation (supplied AI Pod and ALI tokens)
	 * @param podId ID of the AI Pod locked (transferred) to newly created iNFT
	 * @param linkPrice amount of ALI tokens locked (transferred) to newly created iNFT
	 * @param nftContract target NFT smart contract
	 * @param nftId target NFT ID (where this iNFT binds to and belongs to)
	 * @param personalityPrompt personality prompt for the minted iNFT
	 */
	event Linked(
		address indexed _by,
		uint64 iNftId,
		address payer,
		uint64 podId,
		uint96 linkPrice,
		address nftContract,
		uint256 nftId,
		uint256 personalityPrompt
	);

	/**
	 * @dev Fired in unlink() when an existing iNFT gets destroyed
	 *
	 * @param _by an address which executed the unlink function
	 * @param iNftId ID of the iNFT burnt
	 * @param recipient and address which received unlocked AI Pod and ALI tokens
	 * @param unlinkFee service fee in ALI tokens withheld
	 */
	event Unlinked(
		address indexed _by,
		uint64 iNftId,
		address recipient,
		uint96 unlinkFee
	);

	/**
	 * @dev Creates/deploys an iNFT Linker instance bound to already deployed
	 *      iNFT, AI Pod and ALI Token instances
	 *
	 * @param _iNft address of the deployed iNFT instance the iNFT Linker is bound to
	 * @param _pod address of the deployed AI Pod instance the iNFT Linker is bound to
	 * @param _ali address of the deployed ALI ERC20 Token instance the iNFT Linker is bound to
	 */
	constructor(address _iNft, address _pod, address _ali) {
		// verify inputs are set
		require(_iNft != address(0), "iNFT addr is not set");
		require(_pod != address(0), "AI Pod addr is not set");
		require(_ali != address(0), "ALI Token addr is not set");

		// TODO: verify _iNft, _pod and _ali are valid

		// setup smart contract internal state
		iNftContract = _iNft;
		podContract = _pod;
		aliContract = _ali;
	}

	/**
	 * @notice Links given AI Pod with the given NFT and forms an iNFT.
	 *      AI Pod specified and `linkPrice` ALI are transferred into minted iNFT
	 *      and are effectively locked within an iNFT until it is destructed (burnt)
	 *
	 * @dev AI Pod and ALI tokens are transferred from the transaction sender account,
	 *      by iNFT smart contract
	 * @dev Sender must approve both AI Pod and ALI tokens transfers to be performed by iNFT contract
	 *
	 * @param podId AI Pod ID to be locked into iNFT
	 * @param nftContract NFT address iNFT to be linked to
	 * @param nftId NFT ID iNFT to be linked to
	 */
	// TODO: consider a mechanism when sender sends tokens directly to the linker and linking happens in a callback
	function link(uint64 podId, address nftContract, uint256 nftId) public {
		// verify AI Pod exists
		require(AiPodERC721v1(podContract).exists(podId), "AI Pod doesn't exist");
		// verify NFT contract is either whitelisted or any NFT contract is allowed globally
		require(whitelistedNftContracts[nftContract] || isFeatureEnabled(FEATURE_ALLOW_ANY_NFT_CONTRACT), "not a whitelisted NFT contract");

		// TODO: do we need any rules here on which AI Pods can be linked to which NFTs?

		// get a link to an iNFT contract to perform several actions with it
		IntelligentNFTv1 iNFT = IntelligentNFTv1(iNftContract);
		// get the next iNFT ID which can be safely minted (doesn't yet exist)
		// TODO: this doesn't work since totalSupply may decrease (thanks to Zaid Munir for reviewing that)
		uint64 nextId = uint64(iNFT.totalSupply()) + 1;
		// mint the iNFT linking it to the AI Pod provided - delegate to `IntelligentNFTv1.mint`
		// TODO: where do we take personalityPrompt from?
		uint256 personalityPrompt = 0x0;
		iNFT.mint(nextId, msg.sender, personalityPrompt, podId, linkPrice, nftContract, nftId);

		// emit an event
		emit Linked(msg.sender, nextId, msg.sender, podId, linkPrice, nftContract, nftId, personalityPrompt);
	}

	/**
	 * @notice Destroys given iNFT, unlinking it from underlying NFT and unlocking
	 *      the AI Pod and ALI tokens locked in iNFT.
	 *      AI Pod and ALI tokens are transferred to the underlying NFT owner,
	 *      service fee (see `unlinkFee`) in ALI tokens is withheld
	 *
	 * @dev Can be executed only by iNFT owner (effectively underlying NFT owner)
	 *
	 * @param iNftId ID of the iNFT to unlink
	 */
	function unlink(uint64 iNftId) public {
		// get a link to an iNFT contract to perform several actions with it
		IntelligentNFTv1 iNFT = IntelligentNFTv1(iNftContract);

		// verify the transaction is executed by iNFT owner (effectively by underlying NFT owner)
		require(iNFT.ownerOf(iNftId) == msg.sender, "not an iNFT owner");

		// burn the iNFT unlocking the AI Pod and ALI tokens - delegate to `IntelligentNFTv1.burn`
		iNFT.burn(iNftId, unlinkFee);

		// TODO: handle the `unlinkFee` ALI tokens receipt

		// emit an event
		emit Unlinked(msg.sender, iNftId, msg.sender, unlinkFee);
	}

	// TODO: consider adding similar to `unlink` function which unlinks by NFT instead of iNFT
	// TODO: function unlink(address nftContract, uint256 nftId) public;

	// TODO: consider adding functions to unlink + link in a single transaction
}

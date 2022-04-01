%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.uint256 import uint256_add

from starkware.cairo.common.math import assert_not_zero, assert_le

from contracts.token.ERC20.IERC20 import IERC20

from contracts.token.ERC721.ERC721_base import (
    ERC721_name, ERC721_symbol, ERC721_balanceOf, ERC721_ownerOf, ERC721_getApproved,
    ERC721_isApprovedForAll, ERC721_mint, ERC721_burn, ERC721_initializer, ERC721_approve,
    ERC721_setApprovalForAll, ERC721_transferFrom, ERC721_safeTransferFrom)

from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        name : felt, symbol : felt, to_ : felt, registration_price_felt : felt):
    # IDEA : set which token is allowed to be used to pay?
    # + make a setter to add  + remove other currencies?
    ERC721_initializer(name, symbol)
    let to = to_
    let token_id : Uint256 = Uint256(1, 0)
    current_token_id_storage.write(token_id)
    ERC721_mint(to, token_id)
    assignTokenTo(to, token_id)
    # so we can make it change or into a dutch auction, or something else
    let registration_price : Uint256 = Uint256(registration_price_felt, 0)
    registration_price_storage.write(registration_price)
    return ()
end

#
# Declaring storage vars
#

@storage_var
func sex_storage(token_id : Uint256) -> (value : felt):
end
@storage_var
func legs_storage(token_id : Uint256) -> (value : felt):
end
@storage_var
func wings_storage(token_id : Uint256) -> (value : felt):
end

@storage_var
func current_token_id_storage() -> (token_id : Uint256):
end

@storage_var
func tokens_by_owner_length_storage(account : felt) -> (number_of_tokens_owned : felt):
end

@storage_var
func tokens_numbers_by_owner_and_index_storage(account : felt, index : felt) -> (
        token_id : Uint256):
end

@storage_var
func registration_price_storage() -> (price : Uint256):
end

@storage_var
func breeders_storage(account : felt) -> (is_breeder : felt):
end

#
# Events
#

@event
func MintingDoneFrom(account : felt, tokenId : Uint256):
end
# TODO add event new breeder?

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC721_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC721_symbol()
    return (symbol)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
        balance : Uint256):
    let (balance : Uint256) = ERC721_balanceOf(owner)
    return (balance)
end

@view
func ownerOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : Uint256) -> (owner : felt):
    let (owner : felt) = ERC721_ownerOf(token_id)
    return (owner)
end

@view
func getApproved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : Uint256) -> (approved : felt):
    let (approved : felt) = ERC721_getApproved(token_id)
    return (approved)
end

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt) -> (is_approved : felt):
    let (is_approved : felt) = ERC721_isApprovedForAll(owner, operator)
    return (is_approved)
end

@view
func get_animal_characteristics{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : Uint256) -> (sex : felt, legs : felt, wings : felt):
    let (sex) = sex_storage.read(token_id)
    let (legs) = legs_storage.read(token_id)
    let (wings) = wings_storage.read(token_id)
    return (sex, legs, wings)
end

@view
func token_of_owner_by_index{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, index : felt) -> (token_id : Uint256):
    let (token_id) = tokens_numbers_by_owner_and_index_storage.read(account, index)
    return (token_id)
end

@view
func registration_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        price : Uint256):
    return registration_price_storage.read()
end

@view
func is_breeder{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (is_approved : felt):
    let (sender_address) = get_caller_address()
    let (is_approved) = breeders_storage.read(sender_address)
    return (is_approved)
end

#
# Externals
#

@external
func declare_animal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sex : felt, legs : felt, wings : felt) -> (token_id : Uint256):
    alloc_locals
    let (sender_address) = get_caller_address()
    let (isBreeder) = is_breeder(sender_address)  # Make an Ownable_only_owner use ==> checkCanKill
    with_attr error_message("You are not a breader, you can't create an animal"):
        assert isBreeder = 1
    end
    # get next token id
    let (next_token_id) = nextTokenId()
    # write all its attributes
    sex_storage.write(next_token_id, sex)
    legs_storage.write(next_token_id, legs)
    wings_storage.write(next_token_id, wings)
    # mint it to the caller of this method
    ERC721_mint(sender_address, next_token_id)
    # update current_token_id_storage
    current_token_id_storage.write(next_token_id)
    assignTokenTo(sender_address, next_token_id)
    MintingDoneFrom.emit(account=sender_address, tokenId=next_token_id)
    return (next_token_id)
end

@external
func declare_dead_animal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : Uint256):
    alloc_locals
    let (sender_address) = get_caller_address()
    checkCanKill(sender_address, token_id)
    # burn token
    ERC721_burn(token_id)
    removeTokenTo(sender_address, token_id)
    resetCarac(token_id)
    return ()
end

@external
func register_me_as_breeder{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (is_added : felt):
    chargeFeeToSender()
    let (sender_address) = get_caller_address()
    breeders_storage.write(sender_address, 1)
    return (1)
end

@external
func approve{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : Uint256):
    ERC721_approve(to, token_id)
    return ()
end

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    ERC721_setApprovalForAll(operator, approved)
    return ()
end

@external
func transferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, token_id : Uint256):
    ERC721_transferFrom(_from, to, token_id)
    moveTokenFromTo(_from, to, token_id)
    return ()
end

@external
func safeTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, token_id : Uint256, data_len : felt, data : felt*):
    ERC721_safeTransferFrom(_from, to, token_id, data_len, data)
    moveTokenFromTo(_from, to, token_id)
    return ()
end

#
# Internal functions
#

func nextTokenId{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        next_token_id : Uint256):
    let (current_token_id) = current_token_id_storage.read()
    let one_as_uint256 : Uint256 = Uint256(1, 0)
    let (next_token_id, carry) = uint256_add(current_token_id, one_as_uint256)
    return (next_token_id)
end

func assignTokenTo{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, token_id : Uint256) -> ():
    let (current_length_for_user) = tokens_by_owner_length_storage.read(to)
    tokens_numbers_by_owner_and_index_storage.write(to, current_length_for_user, token_id)
    tokens_by_owner_length_storage.write(to, current_length_for_user + 1)
    return ()
end

func removeTokenTo{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, token_id : Uint256) -> ():
    let (current_length_for_user) = tokens_by_owner_length_storage.read(to)
    # trying to delete when no more token to delete
    assert_not_zero(current_length_for_user)
    # TODO DELETE FROM ARRAY!
    tokens_by_owner_length_storage.write(to, current_length_for_user - 1)
    return ()
end

func moveTokenFromTo{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, token_id : Uint256) -> ():
    removeTokenTo(_from, token_id)
    assignTokenTo(to, token_id)
    return ()
end

func resetCarac{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : Uint256) -> ():
    sex_storage.write(token_id, 0)
    legs_storage.write(token_id, 0)
    wings_storage.write(token_id, 0)
    return ()
end

func chargeFeeToSender{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    # TODO make a way to say which are the tokens allowed ==> Only owwner
    let sender = 0x07ff0a898530b169c5fe6fed9b397a7bbd402973ce2f543965f99d6d4a4c17b8
    let (sender_address) = get_caller_address()
    let (recipient) = get_contract_address()
    let (registrationPrice) = registration_price_storage.read()
    IERC20.transferFrom(sender, sender_address, recipient, registrationPrice)
    return ()
end

func checkCanKill{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender_address : felt, token_id : Uint256) -> ():
    let (owner_of) = ownerOf(token_id)
    with_attr error_message("You can't kill an animal you don't own"):
        assert owner_of = sender_address
    end
    return ()
end

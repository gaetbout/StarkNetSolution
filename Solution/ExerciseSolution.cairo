%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_lt
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from contracts.token.ERC20.IDTKERC20 import IDTKERC20
from contracts.token.ERC20.IERC20 import IERC20
from contracts.token.ERC20.ERC20_base import ERC20_burn

# ONLY OWNER: https://github.com/OpenZeppelin/cairo-contracts/blob/main/src/openzeppelin/access/ownable.cairo
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        contractToGetTokensFrom : felt):
    contract_to_get_token_from_storage.write(contractToGetTokensFrom)
    return ()
end
#
# Events
#
@event
func AmountIncreasedTo(account : felt, amount : Uint256):
end

@event
func AllTokensWithdrawnFor(account : felt, amount : Uint256):
end

#
# Storage vars
#

# Should be able to change it? if yes ==> ONLY OWNER
@storage_var
func contract_to_get_token_from_storage() -> (account : felt):
end

@storage_var
func tokens_in_custody_storage(account : felt) -> (amount : Uint256):
end

@storage_var
func deposit_tracker_token_address_storage() -> (account : felt):
end

#
# Getters
#
@view
func tokens_in_custody{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (amount : Uint256):
    return tokens_in_custody_storage.read(account)
end

@view
func deposit_tracker_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        deposit_tracker_token_address : felt):
    return deposit_tracker_token_address_storage.read()
end

#
# Externals
#
@external
func get_tokens_from_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (amount : Uint256):
    alloc_locals
    let (contractToGetTokensFrom) = get_contract_to_get_token_from()
    let (amountReceived) = IDTKERC20.faucet(contractToGetTokensFrom)
    if amountReceived == 0:
        return (Uint256(0, 0))
    end
    # Faucet gives Uint256(100 * 1000000000000000000, 0) tokens ==> Ugly code, there should be a way to know how much we get...
    increaseCurrentAmountForUser(Uint256(100 * 1000000000000000000, 0))
    return (Uint256(100 * 1000000000000000000, 0))
end

@external
func withdraw_all_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        amount : Uint256):
    alloc_locals
    let (tracker_token_address) = deposit_tracker_token()
    let (sender) = get_contract_to_get_token_from()
    let (recipient_address) = get_caller_address()
    let (amountOfUser) = get_tokens_in_custody_for_user()
    IERC20.transfer(sender, recipient_address, amountOfUser)
    IERC20.burnTo(tracker_token_address, recipient_address, amountOfUser)
    tokens_in_custody_storage.write(recipient_address, Uint256(0, 0))
    AllTokensWithdrawnFor.emit(recipient_address, amountOfUser)
    return (amountOfUser)
end

@external
func deposit_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256) -> (total_amount : Uint256):
    let (contractToGetTokensFrom) = get_contract_to_get_token_from()
    let (sender_address) = get_caller_address()
    let (contract_address) = get_contract_address()
    IERC20.transferFrom(contractToGetTokensFrom, sender_address, contract_address, amount)
    let (amountOfUser) = get_tokens_in_custody_for_user()
    increaseCurrentAmountForUser(amount)
    return get_tokens_in_custody_for_user()
end

@external
func deposit_tracker_token_setter{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        deposit_tracker_token_address : felt) -> ():
    # ONLY OWNER
    deposit_tracker_token_address_storage.write(deposit_tracker_token_address)
    return ()
end

@external
func set_value_for{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt, amount : Uint256) -> ():
    # ONLY OWNER
    tokens_in_custody_storage.write(address, amount)
    return ()
end

#
# Internals
#
func increaseCurrentAmountForUser{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(amount : Uint256) -> ():
    alloc_locals
    let (lpTokenAddress) = deposit_tracker_token()
    let (caller) = get_caller_address()
    IERC20.mintTo(lpTokenAddress, caller, amount)
    let (currentAmount) = tokens_in_custody_storage.read(caller)
    let (newAmout, _) = uint256_add(currentAmount, amount)
    let (increasing) = uint256_lt(newAmout, currentAmount)
    with_attr error_message("Cannot decrease"):
        assert increasing = 1
    end
    tokens_in_custody_storage.write(caller, newAmout)
    AmountIncreasedTo.emit(caller, newAmout)
    return ()
end

func get_contract_to_get_token_from{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (contract : felt):
    return contract_to_get_token_from_storage.read()
end

func get_tokens_in_custody_for_user{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (amount : Uint256):
    let (caller) = get_caller_address()
    let (amountOfUser) = tokens_in_custody_storage.read(caller)
    return (amountOfUser)
end

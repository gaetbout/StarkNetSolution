%lang starknet
#
# Imports
#
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

#
# Constructor
#
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return ()
end
#
# Events
#
# call using
#    Log.emit("Something", get_caller_address(), 1, 2)
@event
func Log(stringValue : felt, sender_address : felt, value : felt, data : felt):
end

@event
func EventName(account : felt, tokenId : Uint256):
end

#
# Storage vars
#
@storage_var
func name_of_storage(arg1 : felt) -> (returnValue : felt):
end

#
# Getters
#
@view
func someView{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    return ()
end

#
# Externals
#
@external
func someExternalMethod{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    return ()
end

#
# Internals
#
func someInternalMethod{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    return ()
end

#
# Utils
#
func assertExpectedActualMessage{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        expected : felt, actual : felt, message : felt):
    alloc_locals

    local msg = message
    with_attr error_message("{msg}"):
        assert expected = actual
    end
    return ()
end

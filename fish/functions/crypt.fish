function dclose
    sudo umount -f /mnt/storage
    sudo cryptsetup close storage
end

function dopen
    set disk $argv[1]
    
    if test -n "$disk"
        sudo cryptsetup open $disk storage
    else
        sudo cryptsetup open /dev/sda4 storage
    end
    
    sudo mount /dev/mapper/storage /mnt/storage
    cd /mnt/storage
end

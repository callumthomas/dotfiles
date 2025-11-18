function last_args 
	history --max 1 | string split ' ' | tail -n +2
end

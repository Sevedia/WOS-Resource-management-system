
for i in string.gmatch("Copper 1 \n", "[^%s\n]*") do 
    print(#i)
end 

print(string.match("Copper 1 \n","[^\n]+%S"))
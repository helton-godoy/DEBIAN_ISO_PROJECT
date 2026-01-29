#+-----------------------------------+
#| Programa: barrasimples            |
#| Autor: Francisco Iago Lira Passos |
#| Data: 19-02-2018                  |
#+-----------------------------------+
#!/bin/bash

coluna=$(tput cols)
linha=$(tput lines)

tput cup 1 0
echo "["
tput cup 1 $coluna
echo "]"

tput cup 1 1
for (( i=0; i<$coluna-2; i++ ))
do
  printf '%.s=' $i
  sleep 0.01
done
echo

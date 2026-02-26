/*
 * Example functions to practice JavaScript
 *
 * Carlos Enrique Rosete Pascual
 * 2026-02-18
 */

"use strict";

function firstNonRepeating(str){
    //Creamos un arreglo vacio para guardar a los candidatos
    const candidates = [];
    //Checamos cada caracter en el str
    for (let i=0;i<str.length; i++){
        //comparamos todos con los candidatos
        let found = false;
        for(let cand of candidates){
            if (cand.char == str[i]){
                cand.count += 1;
                found = true;
            }
        }
        if(!found){
            candidates.push({char:str[i], count:1})
        }
    }
    console.log(candidates);
    //buscar el caracter que solo se repite una vez
    for (let index in candidates){
        if (candidates[index].count == 1){
            return candidates[index].char;
        }
    }
}

function bubbleSort(arr){
    let sorted = false;
    // Repetimos el proceso hasta que no haya más intercambios
    while (!sorted){
        sorted = true;
        // Recorremos el arreglo comparando pares adyacentes
        for (let i=0; i<arr.length-1; i++){
            // Si el actual es mayor al siguiente, los intercambiamos
            if (arr[i] > arr[i+1]){
                let temp = arr[i];
                arr[i] = arr[i+1];
                arr[i+1] = temp;
                sorted = false; // Marcamos que hubo un cambio
            }
        }
    }
    return arr;
}

function invertArray(arr){
    let newArr = [];
    // Recorremos el arreglo original de atrás hacia adelante
    for (let i=arr.length-1; i>=0; i--){
        // Agregamos cada elemento al nuevo arreglo
        newArr.push(arr[i]);
    }
    return newArr;
}

function invertArrayInplace(arr){
    // Recorremos solo hasta la mitad del arreglo
    for (let i=0; i<arr.length/2; i++){
        // Intercambiamos los extremos opuestos usando una variable temporal
        let temp = arr[i];
        arr[i] = arr[arr.length-1-i];
        arr[arr.length-1-i] = temp;
    }
    return arr;
}

function capitalize(str){
    let frase ="";
    // Revisamos cada letra de la cadena
    for (let i=0; i<str.length; i++){
        // Si es la primera letra o sigue a un espacio, la hacemos mayúscula
        if (i == 0){
            frase += str[i].toUpperCase();
        } else if (str[i-1] == " "){
            frase += str[i].toUpperCase();
        } else {
            frase += str[i];
        }
    }
    return frase;
}

function mcd(a, b){
    // Caso base: si alguno es cero, el mcd es cero (por definición en este código)
    if (a == 0 || b == 0){
        return 0;
    } else if (a == b){
        // Si son iguales, encontramos el mcd
        return a;
    } else if (a > b){
        // Restamos el menor al mayor recursivamente
        return mcd(a-b, b);
    } else {
        return mcd(a, b-a);
    }
}

function hackerSpeak(str){
    let hacker = "";
    // Evaluamos cada letra para reemplazarla por su numero
    for (let i=0; i<str.length; i++){
        switch (str[i]){
            case "a":
                hacker += "4";
                break;
            case "e":
                hacker += "3";
                break;
            case "i":
                hacker += "1";
                break;
            case "o":
                hacker += "0";
                break;
            case "s":
                hacker += "5";
                break;
            default:
                // Si no es una letra especial, dejamos la letra original
                hacker += str[i];
        }
    }
    return hacker;
}

function factorize(n){
    let factors = [];
    // Probamos todos los números desde 1 hasta n dentro del arreglo
    for (let i=1; i<=n; i++){
        // Si el residuo es cero, i es un factor
        if (n % i == 0){
            factors.push(i);
        }
    }
    return factors;
}

function deduplicate(arr){
    let newArr = [];
    // Recorremos el arreglo original
    for (let i=0; i<arr.length; i++){
        // Si el elemento no está en el nuevo arreglo, lo agregamos a la cuenta
        if (!newArr.includes(arr[i])){
            newArr.push(arr[i]);
        }
    }
    return newArr;
}

function findShortestString(arr){
    // Si el arreglo está vacío, regresamos cero
    if (arr.length == 0){
        return 0;
    }
    // Suponemos que el primero es el más corto inicialmente
    let shortest = arr[0].length;
    for (let i=1; i<arr.length; i++){
        // Si encontramos uno con menos caracteres, actualizamos la cuenta
        if (arr[i].length < shortest){
            shortest = arr[i].length;
        }
    }
    return shortest;
}

function isPalindrome(str){
    let izquierda= 0;
    let derecha = str.length-1;
    // Comparamos los extremos moviéndonos hacia el centro
    while (izquierda < derecha){
        // Si las letras no coinciden, no es palíndromo
        if (str[izquierda] != str[derecha]){
            return false;
        }
        izquierda++;
        derecha--;
    }
    return true;
}

function sortStrings(arr){
    // Reutilizamos la lógica de bubbleSort para ordenar cadenas
    return bubbleSort(arr);
}

function stats(arr){
    // Manejo de caso para arreglos vacíos
    if (arr.length == 0){
        return [0, 0];
    } 
    let sum = 0;
    // Calculamos la suma total para obtener el promedio
    for (let i=0; i<arr.length; i++){
        sum += arr[i];
    }
    let promedio = sum/arr.length;

    let count = [];
    let mayor = 0;
    let moda = 0;
    // Buscamos la frecuencia de cada número para hallar la moda
    for (let i = 0; i<arr.length; i++){
        let numI = arr[i];
        if (!count[numI]){
            count[numI] = 1;
        } else {
            count[numI]++;
        }
        // Actualizamos la moda si el número actual aparece más veces
        if (count[numI] > mayor){
            mayor = count[numI];
            moda = numI;
        }
    }
    return [promedio, moda];
}

function popularString(arr){
    if (arr.length == 0){
        return "";
    }
    // Al igual que en stats, pero con strings aplicamos la moda 
    let count = {};
    let mayor = 0;
    let popular = "";
    for (let i=0; i<arr.length; i++){
        let strI = arr[i];
        if (!count[strI]){
            count[strI] = 1;
        } else {
            count[strI]++;
        }
        // Identificamos el string que más se repite
        if (count[strI] > mayor){
            mayor = count[strI];
            popular = strI;
        }
    }
    return popular;
}

function isPowerOf2(n){
    // Las potencias de 2 deben ser mayores o iguales a 1
    if (n < 1){
        return false;
    }
    // Dividimos entre 2 sucesivamente
    while (n > 1){
        // Si en algún punto el residuo no es cero, no es potencia de 2
        if (n % 2 != 0){
            return false;
        }
        n = n / 2;
    }
    return true;
}

function sortDescending(arr){
     // Primero ordenamos de menor a mayor
     bubbleSort(arr);
     // Luego invertimos el arreglo para tenerlo de mayor a menor
     return invertArrayInplace(arr);
}

export {
    firstNonRepeating,
    bubbleSort,
    invertArray,
    invertArrayInplace,
    capitalize,
    mcd,
    hackerSpeak,
    factorize,
    deduplicate,
    findShortestString,
    isPalindrome,
    sortStrings,
    stats,
    popularString,
    isPowerOf2,
    sortDescending,
};

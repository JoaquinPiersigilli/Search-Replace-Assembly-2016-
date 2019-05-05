section .data

	mensajeErrorParametros db  "Se ingresaron mal los parametros", 0xA
	longitudParametros equ $ - mensajeErrorParametros
	
	mensajeAyuda db "Bienvenido a buscar y reemplazar patron. Este programa le permite ingresar un texto ya sea por esta misma consola o a traves de un archivo, buscar un patron (patron1) en dicho texto y reemplazarlo por un segundo patron (patron2).																		 Estos son los parametros que puede usar, tenga en cuenta que los parametros entre corchetes son obligatorios. Si no se especifica ninguno de los parametros opcionales, se le pedirá que ingrese un texto por consola y se le mostrará el resultado en la misma.														    [-h]: Si el primer parametro que ingresa es o comienza con -h, se mostrará una ayuda.					patron1: Indica el patron que usted quiere cambiar en el texto.								    patron2: Toda aparicion de patron1 será reemplazada por patron2. 								[archivo_entrada]: Indica el nombre del archivo en el cual esta contenido el texto sobre el que quiere realizar la busqueda y reemplazo. Si utiliza esta opcion, se buscara el texto en el archivo de entrada y se mostrara el resultado del reemplazo en la consola.														   [archivo_entrada archivo_salida]: Indica tanto el nombre del archivo de entrada como el nombre del archivo de salida. Se buscara el texto en el a chivo de entrada y se mostrara el resultado del ree",0xA

	longitud equ $ - mensajeAyuda

	msgConsola db "Ingrese el texto a analizar y presione Ctrl+D una vez finalizado ", 0xA
	longitudMsgConsola equ $ - msgConsola

	newline db "", 0xA
	longitudNewLine equ $ - newline
	
	tamano equ 999000
	archivoEntrada dd 0
	archivoSalida dd 0
	archivoTemp dw 'archivotemp.txt'
	patron1 dd 0
	patron2 dd 0
	manejadorArchivoEntrada dd 0
	manejadorArchivoSalida dd 0
	manejadorArchivoTemp dd 0
	
section .bss
	buffer	resb 999000
	bufferAux resb 999000

section .text	
	global _start


_start:
	pop ebx			;obtengo el argc
	cmp ebx, 2		;argc es la cantidad de parametros mas 1 que es el nombre del programa
	jl errParametros
	cmp ebx, 6		
	jg errParametros

	;; si llego aca se ingreso una cantidad correcta de parametros.
	
	mov edx, ebx 		;salvo la cantidad de parametros
	pop ebx			;elimino nombre de programa
	dec edx			;resto uno del total de argc, ahora edx tiene exactamente la cant. de parametros reales

	;; Verifico si es la ayuda
	
	pop ebx			;obtengo primer argumento
	cmp BYTE[ebx] , 2dh 	;Es un guion?
 	jne seguir		;no lei guion, entonces debe aparecer el patron1 y seguido a él, el patron2
	inc ebx			;lei guion sigo
	cmp BYTE [ebx], 68h	;¿Es una h?
	jne errParametros	;El unico parametro valido con un guion que lo precede es -h pero se ingreso otra letra despues del guion.
	je ayuda		;lei h muestro ayuda

	
ayuda:		
	mov edx, longitud
	mov ecx, mensajeAyuda
 	mov ebx, 0
	mov eax, 4
	int 80h
	mov eax, 1		;syscall exit
	mov ebx, 0		
	int 80h		

seguir:

	;; Estando aca, la cantidad de parametros sólo puede ser 2, 3 ó 4, en cada uno de los tres casos se procede distinto aunque en todos los casos deben estar los 2 patrones primero.
	;; en edx había guardado la cantidad exacta de parametros y llegue aca sin sobreescribirlos.

	mov [patron1], ebx		  ;guardo patron1
	pop ebx				  ;ebx contiene ahora el patron2
	mov [patron2], ebx      	  ;guardo patron2

	;;edx sigue teniendo la cantidad de parametros reales contando patron1 y patron2 pero el proximo pop ebx pondrá en  	      ebx el parametro que le sigue a patron2 solo en caso de que haya mas de 2 parametros.

	cmp edx, 2
	je dosParametros
	cmp edx, 3
	je tresParametros
	cmp edx, 4
	je cuatroParametros
	jne hubo_error
	

dosParametros:

	call mensajeConsola

	mov edx, longitudNewLine
	mov ecx, newline
	mov ebx, 0
	mov eax, 4
	int 80h
	
	mov eax, 6
	mov ebx, [manejadorArchivoSalida]
	int 0x80
	test eax,eax
	js hubo_error 		;error anormal porque no se trata de archivo de entrada ni de salida, sino el temporal.
	
	mov eax, 1 		;stdout es el filehandler 1
	mov [manejadorArchivoSalida], eax

	mov eax, 5			  ;syscall open existing file
	mov ebx, archivoTemp        	  ;parametro de syscall
	mov ecx, 0			  ;parametro de syscall
	int 0x80			  ;llamada al syscall
	test eax, eax
	js hubo_error		;error anormal porque no se trata del archivo de entrada ni del de salida, sino del temporal
	mov [manejadorArchivoEntrada],eax 

	;; ya no necesito el archivo temporal por lo que lo borro.
	mov eax, 10			  ;syscall unlink existing file
	mov ebx, archivoTemp        	  ;parametro de syscall
	int 0x80			  ;llamada al syscall
	test eax, eax
	js hubo_error		;error anormal porque no se trata del archivo de entrada ni del de salida, sino del temporal
	
	call leerFile
	
	jmp comparoConPatron
	
tresParametros:
	;; en esta situacion debo obtener el nombre del archivo de entrada.
	call obtenerArchivo1
	;; resta leer el contenido, hacer el reemplazo y mostrar el resultado en consola
 	mov eax, 1
	mov [manejadorArchivoSalida], eax ;el manejador de archivo de salida en 1 le indica al syscall write que imprima en el stdout (consola)
	call leerFile
	jmp comparoConPatron
		

obtenerArchivo1:
	pop edi	  	 	 	  ;edi contiene la adress que usará la llamada ret
	pop ebx	  	                  ;ebx contiene ahora el nombre del archivo de entrada
	mov [archivoEntrada], ebx   	  ;guardo el nombre del  archivo de entrada
	mov eax, 5			  ;syscall open existing file
	mov ebx,[archivoEntrada]          ;parametro de syscall
	mov ecx, 0			  ;parametro de syscall
	int 0x80			  ;llamada al syscall
	test eax, eax
	js hubo_error1			  ;error en archivo de entrada
	mov [manejadorArchivoEntrada],eax ;
	push edi
	ret

	
obtenerArchivo2:
	pop edi
	pop ebx			 	  ;ebx contiene ahora el nombre del archivo de salida
	mov [archivoSalida], ebx          ;guardo el nombre del  archivo de salida
	mov eax, 8			  ;syscall create and open file
	mov ebx, [archivoSalida]	  ;parametro de syscall
	mov ecx, 644q			  ;parametro de syscall
	int 0x80			  ;llamada al syscall
	test eax, eax
	js hubo_error2		;error en archivo de salida
	mov [manejadorArchivoSalida], eax
	push edi
	ret
	
	
cuatroParametros:

	;; en esta situacion debo obtener el nombre de los 2 archivos y ya puedo sobreescribir edx.
	call obtenerArchivo1
	call obtenerArchivo2
	
	;; acá ya tengo los 2 archivos abiertos, resta hacer la lectura->busqueda de patrones->escritura
	call leerFile

	;; aca ya tengo en ecx el buffer con todos los caracteres del archivo de entrada.
	jmp comparoConPatron


	
caracterMatchShell:
	push ecx		;pusheo la posicion en el buffer del archivo1 donde empezo a coincidir el patron

caracterMatch:
	inc edx			;avanzo al proximo caracter del patron1
	cmp BYTE [edx],0	;si luego de incrementar edx el patron1 se termina quiere decir que coincidio todo el patron
	je finalPatronShell
	inc ecx			;si todavia no llegue al final del patron1, avanzo en el buffer del archivo1
 	mov al, BYTE[ecx]
	cmp al, BYTE[edx]
	je caracterMatch

	;; si sigo aca el patron dejo de coincidir

	mov edi, ecx
	pop ecx
caracterNoMatch
	mov edx, 1
	mov eax, 4
	mov ebx, [manejadorArchivoSalida]
	int 0x80
	mov al, BYTE[ecx]
	cmp al, BYTE[edi]
	je comparoConPatronShell
	inc ecx
	jmp caracterNoMatch

comparoConPatronShell
	inc ecx
	
comparoConPatron:
	cmp BYTE [ecx], 0
	je finArchivoUno
	mov al, BYTE [ecx]
	mov edx, [patron1]
	cmp al, BYTE [edx] 
	je caracterMatchShell
	mov edx, 1 		;longitud a imprimir
	mov eax, 4		;syscall write
	mov ebx, [manejadorArchivoSalida]
	int 0x80
	inc ecx
	jmp comparoConPatron
		

finalPatronShell:
	;; si llegue a esta rutina es que el patron coincidio en alguna parte por lo que debo imprimir el patron2
	push ecx
	mov ecx, [patron2]
	
finalPatron:	
	mov edx, 1
	mov eax, 4
	mov ebx, [manejadorArchivoSalida]
	int 0x80
	inc ecx
	cmp BYTE [ecx], 0
	jne finalPatron
	pop ecx			;ultima posicion del buffer del archivo1 donde confirmé que coincidio el patron1
	pop edx			;saco la posicion del buffer del archivo1 donde EMPEZO a coincidir el patron1
	jmp comparoConPatronShell
	

	
restauroPatron:
	;; en este metodo restauro el patron e imprimo el caracter.
	mov edx, 1 		;longitud a imprimir
	mov eax, 4		;syscall write
	mov ebx, [manejadorArchivoSalida]
	int 0x80
	inc ecx
	jmp comparoConPatron
		

	
leerFile:	
	mov eax, 3
	mov ebx, [manejadorArchivoEntrada] ;
	mov ecx, buffer
	mov edx, tamano
	int 0x80
	ret 				   ;retorno a la rutina desde donde llame leerFile
	
hubo_error:
	mov ebx,3
	mov eax,1
	int 0x80
	
hubo_error1:
	mov ebx,1
	mov eax,1
	int 0x80
	
hubo_error2:	
	mov ebx,2
	mov eax,1
	int 0x80
	
errParametros:
	;; Se ingreso cantidad menor a 2 o mayor a 6
	mov edx, longitudParametros
	mov ecx, mensajeErrorParametros
 	mov ebx, 0
	mov eax, 4
	int 80h
	mov eax, 1
	mov ebx, 3		;terminacion anormal por error en la cantidad de parametros.
	int 80h

finArchivoUno:
	;; llegue al final del archivo de entrada por lo que ya no debo escribir en el archivo de salida.
	mov edx, longitudNewLine
	mov ecx, newline
	mov ebx, 0
	mov eax, 4
	int 80h
	
	mov eax,6
	mov ebx,[manejadorArchivoSalida]
	int 0x80
	test eax, eax
	js hubo_error2
	mov ebx,0
	mov eax,1
	int 0x80

mensajeConsola:
	pop edi
	mov edx, longitudMsgConsola
	mov ecx, msgConsola
	mov ebx, 0
	mov eax, 4
	int 80h

	mov eax, 8			  ;syscall create and open file
	mov ebx, archivoTemp		  ;parametro de syscall
	mov ecx, 644q			  ;parametro de syscall
	int 0x80			  ;llamada al syscall
	test eax, eax
	js hubo_error
	mov [manejadorArchivoSalida], eax

otraLinea:	
	mov eax, 3
	mov ebx, 0
	mov ecx, bufferAux
	mov edx, tamano
	int 80h

escribirEnTemp:	
	mov edx, 1
	mov ebx, [manejadorArchivoSalida]
	mov eax, 4
	int 80h
	inc ecx
	cmp BYTE [ecx], 0
	je retorno
        cmp BYTE [ecx], 0ah
	jne escribirEnTemp
	mov edx, 1
	mov ebx, [manejadorArchivoSalida]
	mov eax, 4
	int 80h
	inc ecx
	inc ecx
	jmp otraLinea
	
retorno:
	push edi
	ret

while True:
    dato = input('ingrese dato para guardar o salir')
    if dato.lower() == 'salir':
        print('programa terminado')
        break
    with open('datos.txt', 'a') as archivo:        archivo.write(dato + '\n')
    print('dato guardado')
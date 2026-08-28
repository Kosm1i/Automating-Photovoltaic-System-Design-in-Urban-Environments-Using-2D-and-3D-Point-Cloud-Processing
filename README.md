# Automatyzacja procesu projektowania instalacji fotowoltaicznych w środowisku zurbanizowanym z wykorzystaniem algorytmów przetwarzania chmur punktów 2D i 3D

## O projekcie:
Głównym celem projektu jest opracowanie inteligentnego systemu (i zdanie przedmiotu na studiach), który na podstawie surowych danych geodezyjnych **LiDAR** automatycznie identyfikuje połacie dachowe, analizuje ich geometrię oraz optymalizuje rozmieszczenie paneli fotowoltaicznych. Algorytm uwzględnia dynamiczne zacienienie w pełnym cyklu rocznym, dzięki czemu maksymalizuje efektywność energetyczną projektowanych instalacji.

## Architektura Systemu:

### Pozyskanie i przygotowanie danych
* **Import i transformacja** Wczytanie surowej chmury punktów (.laz) z serwisu **Geoportal**.
* **Filtracja i downsampling** Usunięcie szumu pomiarowego, punktów o niskiej ufności oraz redukcja gęstości chmury punktów w celu optymalizacji złożoności obliczeniowej bez utraty kluczowych cech geometrycznych
* **Normalizacja układu współrzędnych** Transformacja danych z globalnego układu geodezyjnego do lokalnego układu kartezjańskiego

### Segmentacja i Klasyfikacja 3D
* **Oddzielenie obiektów** Oddzielenie punktów reprezentujących grunt od zabudowy i roślinności
* **Ekstrakcja płaszczyzn** Automatyczne wykrywanie wielopołaciowych płaszczyzn dachowych
* **Klasteryzacja DBSCAN** Grupowanie przetworzonych punktów w zdefiniowane obiekty przestrzenne
* **Znalezienie kolizji** Wyodrębnienie infrastruktury dachowej stanowiącej przeszkody i strefy wykluczone z montażu

### Analiza Geometryczna i Rzutowanie (2D/3D)
* **Obliczanie wektorów normalnych** Wyznaczanie wektorów prostopadłych dla każdej wykrytej płaszczyzny
* **Obliczanie parametrów połaci** Wyliczanie kąta nachylenia oraz azymutu dla każdego segmentu dachu
* **Ekstrakcja wektorowa granic** Rzutowanie punktów dachu na płaszczyznę 2D w celu wyznaczenia dokładnych granic połaci

### Analiza Nasłonecznienia i Zacienienia (4D)
* **Model godzinny** Obliczanie wektora padania promieni słonecznych dla dowolnej godziny w roku
* **Ray-tracing** Symulacja rzucania cienia generowanego przez obiekty otoczenia bezpośrednio na płaszczyznę dachu
* **Heatmapa 3D** Wyznaczanie rocznego potencjału energetycznego dla każdego punktu na dachu

### Algorytm Optymalizacji Topologii PV
* **Upakowanie geometryczne** Automatyczne rozmieszczanie prostokątnych modułów PV wewnątrz nieregularnych obrysów dachu
* **Decyzyjność** Bezwzględne odrzucanie lokalizacji, w których prognozowane roczne straty wynikające z zacienienia przekraczają próg wpisany przez użytkownika

## Wykorzystane:
* **Środowisko programistyczne** MATLAB
* **Przetwarzanie danych przestrzennych** Algorytmy operujące na chmurach punktów
* **Kluczowe algorytmy** DBSCAN, Ray-tracing, modelowanie geometrii analitycznej 3D

## Dodatkowe:
* Projekt został stworzony na potrzeby zajęć na studiach. Plan jest stworzony w 100% przez mnie natomiast wykonanie jest wspólne z **AI**.
* Przy wykorzystaniu AI dane i ich poprawność zostały przez mnie potwierdzone jak i przez mojego prowadzącego.
* Czy program jest skuteczny? Tak, moim zdaniem pomoże ci w wyborze dobrych miejsc do ułożenia lecz brałbym na to poprawkę.
* Nie ma uwzględnionych dużo rzeczy, gdyż chodziło tu głównie o algorytmy. Dlatego projekt można śmiało nazwać projektem "studenckim" nie przeznaczonym do polegania na nim.
* Lecz jeśli go użyjesz lub masz jakieś pytania/poprawki, śmiało możesz napisać opinie i odnieść się do tego co stworzyłem.

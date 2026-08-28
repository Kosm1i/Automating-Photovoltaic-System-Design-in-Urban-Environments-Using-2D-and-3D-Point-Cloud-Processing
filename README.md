# Automatyzacja procesu projektowania instalacji fotowoltaicznych w środowisku zurbanizowanym z wykorzystaniem algorytmów przetwarzania chmur punktów 2D i 3D

## O projekcie
Głównym celem projektu jest opracowanie inteligentnego systemu (i zdanie przedmiotu na studiach), który na podstawie surowych danych geodezyjnych LiDAR automatycznie identyfikuje połacie dachowe, analizuje ich geometrię oraz optymalizuje rozmieszczenie paneli fotowoltaicznych. Algorytm uwzględnia dynamiczne zacienienie w pełnym cyklu rocznym, co pozwala na maksymalizację efektywności energetycznej projektowanych instalacji[cite: 1].

## ⚙️ Architektura Systemu (Pipeline)

Proces analizy i optymalizacji został podzielony na 5 głównych etapów:

### Etap I: Pozyskanie i przygotowanie danych
* **Import i transformacja:** Wczytanie surowej chmury punktów z serwisu Geoportal[cite: 1].
* **Filtracja i Downsampling:** Usunięcie szumu pomiarowego, punktów o niskiej ufności oraz redukcja gęstości chmury punktów w celu optymalizacji złożoności obliczeniowej bez utraty kluczowych cech geometrycznych[cite: 1].
* **Normalizacja układu współrzędnych:** Transformacja danych z globalnego układu geodezyjnego (PUWG 1992) do lokalnego układu kartezjańskiego (0,0,0)[cite: 1].

### Etap II: Segmentacja i Klasyfikacja 3D
* **Separacja obiektów:** Oddzielenie punktów reprezentujących grunt od zabudowy i roślinności[cite: 1].
* **Ekstrakcja płaszczyzn:** Automatyczne wykrywanie wielopołaciowych płaszczyzn dachowych[cite: 1].
* **Klasteryzacja DBSCAN:** Grupowanie przetworzonych punktów w zdefiniowane obiekty przestrzenne[cite: 1].
* **Detekcja kolizji:** Wyodrębnienie infrastruktury dachowej stanowiącej przeszkody i strefy wykluczone z montażu[cite: 1].

### Etap III: Analiza Geometryczna i Rzutowanie (2D/3D)
* **Obliczanie wektorów normalnych:** Wyznaczanie wektorów prostopadłych dla każdej wykrytej płaszczyzny[cite: 1].
* **Parametryzacja połaci:** Wyliczanie dokładnego kąta nachylenia oraz azymutu dla każdego segmentu dachu[cite: 1].
* **Ekstrakcja wektorowa obrysów:** Rzutowanie punktów dachu na płaszczyznę 2D w celu wyznaczenia dokładnych granic operacyjnych[cite: 1].

### Etap IV: Analiza Nasłonecznienia i Zacienienia (4D)
* **Model Solarny:** Obliczanie wektora padania promieni słonecznych dla dowolnej godziny w roku[cite: 1].
* **Ray-tracing:** Symulacja rzutowania cienia generowanego przez obiekty otoczenia bezpośrednio na płaszczyznę dachu[cite: 1].
* **Heatmapa 3D:** Wyznaczanie rocznego potencjału energetycznego dla każdego punktu na dachu[cite: 1].

### Etap V: Algorytm Optymalizacji Topologii PV
* **Upakowanie geometryczne:** Automatyczne rozmieszczanie prostokątnych modułów PV wewnątrz nieregularnych obrysów dachu[cite: 1].
* **Kryterium decyzyjne:** Bezwzględne odrzucanie lokalizacji, w których prognozowane roczne straty wynikające z zacienienia przekraczają próg 20%[cite: 1].
* **Szeregowanie elektryczne:** Automatyczne grupowanie rozmieszczonych modułów w łańcuchy elektryczne[cite: 1].


## 🛠 Stos Technologiczny
* **Środowisko programistyczne:** MATLAB, MATLAB App Designer[cite: 1]
* **Przetwarzanie danych przestrzennych:** Algorytmy operujące na chmurach punktów (LiDAR)[cite: 1]
* **Kluczowe algorytmy:** DBSCAN, Ray-tracing, modelowanie geometrii analitycznej 3D[cite: 1]

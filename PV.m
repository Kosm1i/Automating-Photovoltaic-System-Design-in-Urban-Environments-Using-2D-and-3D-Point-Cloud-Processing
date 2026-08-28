disp('ETAP I START');

% Wstaw tutaj swoj plik .laz
filename = 'chmura_punktow_test.laz'; 

laz = lasFileReader(filename);
surowe_pkt = readPointCloud(laz);
fprintf('Wczytano surową chmurę: %d punktów\n', surowe_pkt.Count);


disp('Filtrowanie szumów');
pkt_fitracja = pcdenoise(surowe_pkt, 'NumNeighbors', 50, 'Threshold', 2.0);
usuniete_pkt = surowe_pkt.Count - pkt_fitracja.Count;
fprintf('Usunięto %d punktów szumu (zostało: %d)\n', usuniete_pkt, pkt_fitracja.Count);

disp('Downsampling chmury');
gridStep = 0.25; 
zredukowane_pkt = pcdownsample(pkt_fitracja, 'gridAverage', gridStep);
fprintf('Zredukowano do %d punktów (siatka %.2fm)\n', zredukowane_pkt.Count, gridStep);

disp('Normalizacja do układu kartezjańskiego (0,0,0)');
xyz = zredukowane_pkt.Location;
offset = min(xyz); 
xyz_lokalne = xyz - offset;

pkt_lokalne = pointCloud(xyz_lokalne);
fprintf('Wektor przesunięcia to: [%.2f, %.2f, %.2f]\n', offset(1), offset(2), offset(3));

disp('ETAP I KONIEC');
figure('Name', 'ETAP I', 'Color', [0.1 0.1 0.1]);

pcshow(pkt_lokalne.Location, pkt_lokalne.Location(:,3), 'MarkerSize', 15);
colormap(jet);
colorbar('Color', 'w');

title('ETAP I', 'Color', 'w');
xlabel('X lokalne [m]', 'Color', 'w'); 
ylabel('Y lokalne [m]', 'Color', 'w'); 
zlabel('Z lokalne [m]', 'Color', 'w');
set(gca, 'Color', [0.2 0.2 0.2], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');

disp('ETAP II START');
disp('Oddzielenie gruntu od budynków/roślinności');
pkt_ziemi        = 1.0;  
pkt_odciete      = 1.5;  
pkt_sasiedzi     = 15;   
pkt_liscie       = 0.45; 

[~, ziemia_idx, brakziemi_idx] = pcfitplane(pkt_lokalne, pkt_ziemi, [0 0 1], 10);
pkt_chmury_ziemi_1 = select(pkt_lokalne, ziemia_idx);
pkt_chmury_pozostale = select(pkt_lokalne, brakziemi_idx);

wartosci_z = pkt_chmury_pozostale.Location(:, 3);
dolne_idx = find(wartosci_z < pkt_odciete); 
gorne_idx = find(wartosci_z >= pkt_odciete); 
pkt_chmury_ziemi_2 = select(pkt_chmury_pozostale, dolne_idx);
pkt_chmury_obiekt = select(pkt_chmury_pozostale, gorne_idx); 

pkt_chmury_cala_ziemia = pointCloud([pkt_chmury_ziemi_1.Location; pkt_chmury_ziemi_2.Location]);

normalne = pcnormals(pkt_chmury_obiekt, pkt_sasiedzi);
z_normalne = abs(normalne(:,3)); 
indeks_drzew = find(z_normalne < pkt_liscie);  
indeks_dach = find(z_normalne >= pkt_liscie); 

pkt_chmury_drzew = select(pkt_chmury_obiekt, indeks_drzew);
pkt_chmury_dach = select(pkt_chmury_obiekt, indeks_dach); 

disp('Klasteryzacja (DBSCAN)');
pkt_odleglosc_klastra = 1.0; 
pkt_min_klastra = 250;       

[etykiety, liczba_klastrow] = pcsegdist(pkt_chmury_dach, pkt_odleglosc_klastra);
budynki = {};
budynki_liczba = 0;

for i = 1:liczba_klastrow
    idx = find(etykiety == i);
    if length(idx) >= pkt_min_klastra
        budynki_liczba = budynki_liczba + 1;
        budynki{budynki_liczba} = select(pkt_chmury_dach, idx);
    end
end
fprintf('Rozpoznano %d osobnych budynków na osiedlu\n', budynki_liczba);


disp('Ekstrakcja połaci dachowych i kominów');
warning('off', 'vision:ransac:maxTrialsReached'); 

% Konfiguracja
tol_sztywna         = 0.08; 
tol_luzna           = 0.25; 
min_pkt_polaci      = 35;   
max_polaci_na_dom   = 10;   

wszystkie_polacie_dachu = {}; 
wszystkie_przeszkody = [];  
licznik_polaci = 1;

punkty_dachowe_budynku = zeros(budynki_liczba, 1);
najwieksza_polac_budynku = zeros(budynki_liczba, 1);


for b = 1:budynki_liczba
    chmura_reszta = budynki{b};
    iter_budynku = 1;
    
    while chmura_reszta.Count > min_pkt_polaci && iter_budynku <= max_polaci_na_dom
        [model_plaszczyzny, indeksy_sztywne, ~] = pcfitplane(chmura_reszta, tol_sztywna, 'MaxNumTrials', 1000);
        
        if length(indeksy_sztywne) < min_pkt_polaci
            break; 
        end
        
        A = model_plaszczyzny.Parameters(1); B = model_plaszczyzny.Parameters(2);
        C = model_plaszczyzny.Parameters(3); D = model_plaszczyzny.Parameters(4);
        
        Wsp_XYZ = chmura_reszta.Location;
        odleglosci = abs(Wsp_XYZ(:,1)*A + Wsp_XYZ(:,2)*B + Wsp_XYZ(:,3)*C + D) ./ sqrt(A^2 + B^2 + C^2);
        indeksy_luzne = find(odleglosci <= tol_luzna);
        tymczasowa_polac = select(chmura_reszta, indeksy_luzne);
        [etykiety_polaci, liczba_polaci_dbscan] = pcsegdist(tymczasowa_polac, 0.4);
        
        rozmiar_najlepszej = 0;
        idx_najlepszej = [];
        for c = 1:liczba_polaci_dbscan
            c_idx = find(etykiety_polaci == c);
            if length(c_idx) > rozmiar_najlepszej
                rozmiar_najlepszej = length(c_idx);
                idx_najlepszej = c_idx;
            end
        end
        
        indeksy_koncowe = indeksy_luzne(idx_najlepszej);
        
        if length(indeksy_koncowe) < min_pkt_polaci
            chmura_reszta = select(chmura_reszta, setdiff(1:chmura_reszta.Count, indeksy_sztywne));
            continue; 
        end
        
        wszystkie_polacie_dachu{licznik_polaci} = select(chmura_reszta, indeksy_koncowe);
        punkty_dachowe_budynku(b) = punkty_dachowe_budynku(b) + length(indeksy_koncowe);

        if length(indeksy_koncowe) > najwieksza_polac_budynku(b)
            najwieksza_polac_budynku(b) = length(indeksy_koncowe);
        end

        chmura_reszta = select(chmura_reszta, setdiff(1:chmura_reszta.Count, indeksy_koncowe));
        licznik_polaci = licznik_polaci + 1;
        iter_budynku = iter_budynku + 1;
    end
    
    if chmura_reszta.Count > 0
        wszystkie_przeszkody = [wszystkie_przeszkody; chmura_reszta.Location];
    end
end
warning('on', 'vision:ransac:maxTrialsReached');

if ~isempty(wszystkie_przeszkody)
    chmura_przeszkod = pointCloud(wszystkie_przeszkody);
else
    chmura_przeszkod = pointCloud([0 0 0]); 
end
fprintf('Wyciągnięto łącznie %d czystych połaci dachowych\n', length(wszystkie_polacie_dachu));
disp('ETAP II KONIEC');

figure('Name', 'ETAP II', 'Color', [0.1 0.1 0.1]);
hold on;

wszystkie_punkty_cieniujace = [pkt_chmury_drzew.Location; chmura_przeszkod.Location];

if ~isempty(wszystkie_punkty_cieniujace) && size(wszystkie_punkty_cieniujace, 1) > 1
    pcshow(wszystkie_punkty_cieniujace, [0.1 0.6 0.1], 'MarkerSize', 8);
    fprintf('Wyświetlono %d punktów cieniujących (zieleń).\n', size(wszystkie_punkty_cieniujace, 1));
end

mapa_kolorow = lines(length(wszystkie_polacie_dachu));
rng(42); 
wymieszane_kolory = mapa_kolorow(randperm(length(wszystkie_polacie_dachu)), :);

for i = 1:length(wszystkie_polacie_dachu)
    pcshow(wszystkie_polacie_dachu{i}.Location, wymieszane_kolory(i,:), 'MarkerSize', 15);
end
hold off;

% Konfiguracja (usuwanie garazy/drzew)
prawdziwe_domy = [];
min_suma_m2 = 35;        
min_glowny_spad_m2 = 15; 
gestosc = 16;            

for b = 1:budynki_liczba
    zbadana_suma_m2 = punkty_dachowe_budynku(b) / gestosc;
    najwiekszy_spad_m2 = najwieksza_polac_budynku(b) / gestosc;
    
    if zbadana_suma_m2 >= min_suma_m2 && najwiekszy_spad_m2 >= min_glowny_spad_m2
        prawdziwe_domy = [prawdziwe_domy, b];
    end
end
fprintf('Wykryto %d głównych budynków (ID: %s)\n', length(prawdziwe_domy), num2str(prawdziwe_domy));
    
for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i); 
    
    if b > budynki_liczba || isempty(budynki{b}.Location)
        continue;
    end
    
    xyz_budynku = budynki{b}.Location;
    srodek_x = median(xyz_budynku(:, 1));
    srodek_y = median(xyz_budynku(:, 2));
    najwyzszy_z = max(xyz_budynku(:, 3)) + 3.0; 
    
    text(srodek_x, srodek_y, najwyzszy_z, sprintf('%d', b), ...
        'Color', 'white', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'BackgroundColor', 'black', 'Margin', 1);
end

title('ETAP II', 'Color', 'w');
xlabel('X lokalne [m]', 'Color', 'w'); 
ylabel('Y lokalne [m]', 'Color', 'w'); 
zlabel('Z lokalne [m]', 'Color', 'w');
set(gca, 'Color', [0.2 0.2 0.2], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');

disp('ETAP III START');
disp('Wyznaczanie wektorów normalnych, kątów nachylenia i azymutu');

dane_dachow = struct('id', {}, 'budynek_id', {}, 'chmura', {}, 'wektor_normalny', {}, 'nachylenie', {}, 'azymut', {}, 'powierzchnia_szac', {});
liczba_polaci = length(wszystkie_polacie_dachu);

for i = 1:liczba_polaci
    chmura_polaci = wszystkie_polacie_dachu{i};
    xyz = chmura_polaci.Location;
    srodek_ciezkosci = mean(xyz, 1);
    min_dystans = inf;
    przypisany_dom = 0;
    for b = 1:budynki_liczba
        srodek_domu = mean(budynki{b}.Location, 1);
        dystans = norm(srodek_ciezkosci(1:2) - srodek_domu(1:2));
        if dystans < min_dystans
            min_dystans = dystans;
            przypisany_dom = b;
        end
    end
    
    xyz_zcentrowane = xyz - srodek_ciezkosci;
    [wektory_wlasne, ~] = eig(cov(xyz_zcentrowane));
    normalny = wektory_wlasne(:, 1)'; 
    
    if normalny(3) < 0
        normalny = -normalny;
    end
    
    nz = min(max(normalny(3), -1), 1); 
    nachylenie_rad = acos(nz);
    nachylenie_deg = nachylenie_rad * (180/pi);
    
    azymut_deg = atan2d(normalny(1), normalny(2));
    if azymut_deg < 0
        azymut_deg = azymut_deg + 360;
    end
    
    powierzchnia_szacunkowa = (chmura_polaci.Count * (gridStep^2)) / cos(nachylenie_rad);
    
    dane_dachow(i).id = i;
    dane_dachow(i).budynek_id = przypisany_dom;
    dane_dachow(i).chmura = chmura_polaci;
    dane_dachow(i).wektor_normalny = normalny;
    dane_dachow(i).nachylenie = nachylenie_deg;
    dane_dachow(i).azymut = azymut_deg;
    dane_dachow(i).powierzchnia_szac = powierzchnia_szacunkowa;
end

disp('    Raport analizy fotowoltanicznej');

for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i);
    idx_polaci_domu = find([dane_dachow.budynek_id] == b);
    polacie_domu = dane_dachow(idx_polaci_domu);
    
    [~, sort_idx] = sort([polacie_domu.powierzchnia_szac], 'descend');
    polacie_domu_posortowane = polacie_domu(sort_idx);
    
    fprintf('\nID budynku: %d (Suma wykrytych płaszczyzn: %d)\n', b, length(polacie_domu));
    fprintf('%-5s | %-12s | %-10s | %-15s\n', 'ID', 'Nachylenie', 'Azymut', 'Szacowana powierzchnia w m2');
    disp('----------------------------------------------------------------');
    
    if isempty(polacie_domu_posortowane)
        disp('Brak danych o połaciach');
        continue;
    end
    limit = min(5, length(polacie_domu_posortowane));
    for k = 1:limit
        p = polacie_domu_posortowane(k);
        fprintf('%-5d | %-8.1f st. | %-6.1f st. | %-10.1f\n', ...
            p.id, p.nachylenie, p.azymut, p.powierzchnia_szac);
    end
end

disp('Rzutowanie do 2D i generowanie obrysów');

for i = 1:liczba_polaci
    xyz = dane_dachow(i).chmura.Location;
    punkty_2d = double(xyz(:, 1:2)); 
    
    if size(punkty_2d, 1) > 3
        idx_obrysu = boundary(punkty_2d(:,1), punkty_2d(:,2), 0.4);
        dane_dachow(i).obrys_2d = punkty_2d(idx_obrysu, :);
    else
        dane_dachow(i).obrys_2d = []; 
    end
end

disp('ETAP III KONIEC');
figure('Name', 'ETAP III', 'Color', 'w');
hold on;
axis equal;
grid on;

colormap_l = lines(liczba_polaci);

for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i);
    idx_polaci_domu = find([dane_dachow.budynek_id] == b);
    
    for k = 1:length(idx_polaci_domu)
        p_idx = idx_polaci_domu(k);
        obrys = dane_dachow(p_idx).obrys_2d;
        
        if ~isempty(obrys) && dane_dachow(p_idx).powierzchnia_szac > 25
            plot(obrys(:,1), obrys(:,2), '-', 'LineWidth', 2, 'Color', colormap_l(p_idx,:));
            srodek = mean(obrys);
            text(srodek(1), srodek(2), sprintf('ID:%d', dane_dachow(p_idx).id), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end
    end
end
hold off;
title('Obrysy 2D dachów');
xlabel('X [m]'); ylabel('Y [m]');

disp('ETAP IV START');
disp('Model Solarny (Obliczanie pozycji słońca na niebie)');

szer_geo = ?; 
dlug_geo = ?; 
strefa   = ?;         
dzien_roku = 172; 
godziny = 0:1:23; 
dane_slonca = struct('godzina', {}, 'azymut', {}, 'elewacja', {}, 'wektor_promienia', {});

for g = 1:length(godziny)
    godzina = godziny(g);
    
    deklinacja = 23.45 * sind(360 * (284 + dzien_roku) / 365);
    
    B = 360 * (dzien_roku - 81) / 365;
    EoT = 9.87 * sind(2*B) - 7.53 * cosd(B) - 1.5 * sind(B);
    
    korekta_dlugosci = 4 * (dlug_geo - 15 * strefa); 
    Czas_Sloneczny = godzina + (EoT + korekta_dlugosci) / 60;
    kat_godzinny = 15 * (Czas_Sloneczny - 12);
    
    elewacja = asind(sind(szer_geo) * sind(deklinacja) + ...
               cosd(szer_geo) * cosd(deklinacja) * cosd(kat_godzinny));
           
    cos_azymut = (sind(elewacja) * sind(szer_geo) - sind(deklinacja)) / ...
                 (cosd(elewacja) * cosd(szer_geo));
    cos_azymut = max(min(cos_azymut, 1), -1); 
    azymut = acosd(cos_azymut);
    
    if kat_godzinny > 0
        azymut = 360 - azymut;
    end
    
    wektor_x = -cosd(elewacja) * sind(azymut);
    wektor_y = -cosd(elewacja) * cosd(azymut);
    wektor_z = -sind(elewacja);
    wektor_promienia = [wektor_x, wektor_y, wektor_z];
    
    dane_slonca(g).godzina = godzina;
    dane_slonca(g).azymut = azymut;
    dane_slonca(g).elewacja = elewacja;
    dane_slonca(g).wektor_promienia = wektor_promienia / norm(wektor_promienia); 
end

disp(' ');
disp('Ścieżka słońca');
fprintf('%-8s | %-12s | %-12s\n', 'Godzina', 'Azymut [st]', 'Elewacja [st]');
disp('------------------------------------------');
for g = 1:length(godziny)
    fprintf('%02d:00    | %-12.1f | %-12.1f\n', ...
        dane_slonca(g).godzina, dane_slonca(g).azymut, dane_slonca(g).elewacja);
end

disp('Ray-Tracing (Analiza Cienia) i generowanie heatmapy');

przeszkody_xyz = wszystkie_punkty_cieniujace;
promien_cienia = 0.5;

for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i);
    idx_polaci = find([dane_dachow.budynek_id] == b);
    for k = 1:length(idx_polaci)
        p = idx_polaci(k);
        dane_dachow(p).zacienienie_godziny = zeros(dane_dachow(p).chmura.Count, 1);
    end
end

for g = 1:length(godziny)
    v_sun = dane_slonca(g).wektor_promienia;
    jest_noc = (dane_slonca(g).elewacja <= 0);
    for i = 1:length(prawdziwe_domy)
        b = prawdziwe_domy(i);
        idx_polaci = find([dane_dachow.budynek_id] == b);
        
        for k = 1:length(idx_polaci)
            p = idx_polaci(k);
            
            if dane_dachow(p).powierzchnia_szac < 15
                continue;
            end
            if jest_noc
                dane_dachow(p).zacienienie_godziny = dane_dachow(p).zacienienie_godziny + 1;
                continue;
            end
            n = dane_dachow(p).wektor_normalny;
            
            if dot(n, v_sun) >= 0
                dane_dachow(p).zacienienie_godziny = dane_dachow(p).zacienienie_godziny + 1;
                continue; 
            end
            
            srodek = mean(dane_dachow(p).chmura.Location, 1);
            D = -dot(n, srodek);
            
            den = dot(n, v_sun);
            t = -(przeszkody_xyz * n' + D) / den;
            
            valid_obs = (t > 0) & (t < 50);
            
            if any(valid_obs)
                punkty_cienia = przeszkody_xyz(valid_obs, :) + t(valid_obs) .* v_sun;
                
                for pkt_idx = 1:dane_dachow(p).chmura.Count
                    punkt_dachu = dane_dachow(p).chmura.Location(pkt_idx, :);
                    dystanse = sqrt(sum((punkty_cienia - punkt_dachu).^2, 2));
                    if min(dystanse) <= promien_cienia
                        dane_dachow(p).zacienienie_godziny(pkt_idx) = dane_dachow(p).zacienienie_godziny(pkt_idx) + 1;
                    end
                end
            end
        end
    end
end
disp('ETAP IV KONIEC');

figure('Name', 'ETAP IV', 'Color', [0.1 0.1 0.1]);
hold on;

cmap = jet(25); 
colormap(flipud(cmap)); 
cbar = colorbar;
cbar.Color = 'w';
cbar.Label.String = 'Godziny w cieniu';
clim([0 24]);

for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i);
    idx_polaci = find([dane_dachow.budynek_id] == b);
    for k = 1:length(idx_polaci)
        p = idx_polaci(k);
        if dane_dachow(p).powierzchnia_szac >= 15
            pcshow(dane_dachow(p).chmura.Location, dane_dachow(p).zacienienie_godziny, 'MarkerSize', 25);
        end
    end
end
hold off;
title('ETAP IV', 'Color', 'w');
set(gca, 'Color', [0.2 0.2 0.2], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');

disp('ETAP V START');
disp('Algorytm geometrycznego pakowania paneli 2D');

% Konfiguracja (optymalna dla paneli)
panel_szerokosc = 1.13; 
panel_dlugosc = 1.72;   
margines = 0.15;        
zapas_krawedz = 0.3;    

limit_cienia = 14;           
min_paneli_na_polaci = 4;    

figure('Name', 'ETAP V', 'Color', 'w');
hold on; 
axis equal; 
grid on;
title('Projekt Instalacji PV (z wykluczeniem stref zacienionych i małych połaci)');
xlabel('X lokalne [m]'); ylabel('Y lokalne [m]');

suma_paneli_osiedle = 0;

for i = 1:length(prawdziwe_domy)
    b = prawdziwe_domy(i);
    idx_polaci = find([dane_dachow.budynek_id] == b);
    
    for k = 1:length(idx_polaci)
        p = idx_polaci(k);
        obrys = dane_dachow(p).obrys_2d;
        
        if isempty(obrys) || dane_dachow(p).powierzchnia_szac < 15
            continue;
        end

        plot(obrys(:,1), obrys(:,2), 'k-', 'LineWidth', 1.5);
        kat_nachylenia = dane_dachow(p).nachylenie;
        wymiar_x = panel_szerokosc + margines;
        wymiar_y = (panel_dlugosc + margines) * cosd(kat_nachylenia);
        nx = dane_dachow(p).wektor_normalny(1);
        ny = dane_dachow(p).wektor_normalny(2);
        wektor_spadu = [nx, ny] / norm([nx, ny]);
        wektor_poziomy = [-ny, nx] / norm([-ny, nx]);
        srodek = mean(obrys);
        liczba_paneli_dach = 0;
        zapisane_panele = {}; 
        
        for dx = -15:wymiar_x:15
            for dy = -15:wymiar_y:15
                cx = srodek(1) + dx * wektor_poziomy(1) + dy * wektor_spadu(1);
                cy = srodek(2) + dx * wektor_poziomy(2) + dy * wektor_spadu(2);
                
                if inpolygon(cx, cy, obrys(:,1), obrys(:,2))
                    dystanse = sqrt((dane_dachow(p).chmura.Location(:,1) - cx).^2 + (dane_dachow(p).chmura.Location(:,2) - cy).^2);
                    [min_dystans, idx_najblizszego] = min(dystanse);
                    
                    if min_dystans < 1.0
                        godziny_cienia = dane_dachow(p).zacienienie_godziny(idx_najblizszego);
                        
                        if godziny_cienia <= limit_cienia
                            tx = (wymiar_x/2) + zapas_krawedz;
                            ty = (wymiar_y/2) + zapas_krawedz;
                            
                            t1 = [cx, cy] - tx*wektor_poziomy - ty*wektor_spadu;
                            t2 = [cx, cy] + tx*wektor_poziomy - ty*wektor_spadu;
                            t3 = [cx, cy] + tx*wektor_poziomy + ty*wektor_spadu;
                            t4 = [cx, cy] - tx*wektor_poziomy + ty*wektor_spadu;
                            test_poly = [t1; t2; t3; t4; t1];
                            
                            if all(inpolygon(test_poly(:,1), test_poly(:,2), obrys(:,1), obrys(:,2)))
                                p1 = [cx, cy] - (wymiar_x/2)*wektor_poziomy - (wymiar_y/2)*wektor_spadu;
                                p2 = [cx, cy] + (wymiar_x/2)*wektor_poziomy - (wymiar_y/2)*wektor_spadu;
                                p3 = [cx, cy] + (wymiar_x/2)*wektor_poziomy + (wymiar_y/2)*wektor_spadu;
                                p4 = [cx, cy] - (wymiar_x/2)*wektor_poziomy + (wymiar_y/2)*wektor_spadu;
                                liczba_paneli_dach = liczba_paneli_dach + 1;
                                zapisane_panele{liczba_paneli_dach} = [p1; p2; p3; p4; p1];
                            end
                        end
                    end
                end
            end
        end
        
        if liczba_paneli_dach >= min_paneli_na_polaci
            for nr = 1:liczba_paneli_dach
                poly = zapisane_panele{nr};
                fill(poly(:,1), poly(:,2), [0 0.4 0.8], 'EdgeColor', 'c');
            end
            text(srodek(1), srodek(2), sprintf('%d szt.', liczba_paneli_dach), ...
                'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'k', 'Margin', 1, 'FontSize', 8);
            
            suma_paneli_osiedle = suma_paneli_osiedle + liczba_paneli_dach;
        end
    end
end
hold off;
fprintf('PODSUMOWANIE PROJEKTU: Zainstalowano łącznie %d paneli PV\n', suma_paneli_osiedle);
fprintf('Szacowana moc instalacji: %.1f kWp (przy 400W na panel)\n', suma_paneli_osiedle * 0.4);
disp('ETAP V KONIEC ');

disp('ETAP VI');
disp('Generowanie końcowego raportu inwestycyjnego');

if suma_paneli_osiedle == 0
    disp('Brak zakwalifikowanych paneli do analizy. Zakończenie skryptu.');
    return;
end

% Konfiguracja (ekonomiczna)
moc_kWp = suma_paneli_osiedle * 0.4;        
uzysk_z_kWp = 950;                          
cena_pradu = 1.15;                           
koszt_za_1kWp = 4000;                        
emisyjnosc_co2 = 0.70;                       

produkcja_roczna = moc_kWp * uzysk_z_kWp;              
oszczednosci_roczne = produkcja_roczna * cena_pradu;    
koszt_instalacji = moc_kWp * koszt_za_1kWp;            
czas_zwrotu = koszt_instalacji / oszczednosci_roczne;  
zredukowane_co2 = (produkcja_roczna * emisyjnosc_co2) / 1000; 
posadzone_drzewa = round(zredukowane_co2 * 45);        

disp('           RAPORT KOŃCOWY: POTENCJAŁ SOLARNY OSIEDLA            ');

fprintf(' 1. PODSUMOWANIE TECHNICZNE:\n');
fprintf('    - Zainstalowane panele:    %d szt.\n', suma_paneli_osiedle);
fprintf('    - Całkowita moc systemu:   %.2f kWp\n', moc_kWp);
fprintf('    - Szacowana roczna prod.:  %.0f kWh\n\n', produkcja_roczna);

fprintf(' 2. PODSUMOWANIE FINANSOWE:\n');
fprintf('    - Szacowany koszt montażu: %.2f PLN\n', koszt_instalacji);
fprintf('    - Roczne oszczędności:     %.2f PLN\n', oszczednosci_roczne);
fprintf('    - Czas zwrotu (ROI):       %.1f lat\n\n', czas_zwrotu);

fprintf(' 3. WPŁYW NA ŚRODOWISKO (ESG):\n');
fprintf('    - Redukcja emisji CO2:     %.1f ton/rok\n', zredukowane_co2);
fprintf('    - Ekwiwalent drzew:        %d szt./rok\n', posadzone_drzewa);

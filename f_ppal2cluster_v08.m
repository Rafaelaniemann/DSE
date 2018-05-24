function [ puntos_familia_cluster, familia_cluster_plano ] = f_ppal2cluster_v08( puntos_ppalasignados, planos_pples, ppcluster,vnfamilia)
% [ puntos_familia_cluster, familia_cluster_plano ] = f_ppal2cluster_v07( puntos_ppalasignados, planos_pples, ppcluster,vnfamilia,ksigmas)
% Function that takes the families assigned to each point and calculates
% the clusters.
% Each cluster is a real plane, with the same normal vector
% Input:
% - puntos_ppalasignados: matriz con los puntos y fam a la que pertenece
% - planos_pples: matriz con w y b (�) del vector buzamiento
% - vnfamilia: determina si se le asigna el vector normal del DS (1) o se
% calcula la orientaci�n del plano al cluster (0)
% Output:
% - puntos_familia_cluster: matriz con los puntos, familias y el cluster al que pertenece
% - familia_cluster_plano: matriz que contiene qu� familia, a qu� cluster y
% la ecuaci�n del plano del cl�ster notaci�n Ax+By+Cz+D=0. Es una matriz de
% �ndices
%
% El vector normal puede calcularse ajust�ndo al cl�ster o utilizar
% El de toda la familia. Si vnfamilia=0 el plano se ajusta al cl�ster, si vnfamilia=1 se utiliza la orientaci�n del plano principal. 
% En ambos casos, la posici�n del plano se determina a posteriori.
%vnfamilia=1;
%ksigmas=1.5; % par�metro para ver cuanto se tienen que solapar las funciones de densidad de dos clusters para considerarlos alineados
% A mayor ksigmas, m�s f�cil une los clusters
% valores si fuera normal, que no lo es:
% ksigmas=1 solape mayor al 15,8%
% ksigmas=2 solape mayor al 2,3%
% ksigmas=3 solape mayor al 0,1%
%
%    Copyright (C) {2015}  {Adri�n Riquelme Guill, adririquelme@gmail.com}
%
%    This program is free software; you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation; either version 2 of the License, or
%    any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License along
%   with this program; if not, write to the Free Software Foundation, Inc.,
%   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
%    Discontinuity Set Extractor, Copyright (C) 2015 Adri�n Riquelme Guill
%    Discontinuity Set Extractor comes with ABSOLUTELY NO WARRANTY.
%    This is free software, and you are welcome to redistribute it
%    under certain conditions.

        
ksigmaseps = 2; % par�metro para determinar el radio de b�squeda de puntos en el DBSCAN
% es cu�ntas desviaciones sobre la distancia media del 4 vecino se toma.

% buscamos el n�mero de familias que hay
puntos_familia_cluster=puntos_ppalasignados;
familia_cluster_plano=[];
puntos=puntos_ppalasignados(:,1:3);
familia=puntos_ppalasignados(:,4);
nf=max(familia);

% calculamos el radio eps para el DBSCAN
npb=4; %n�mero de puntos vecinos para la b�squeda de cl�sters
nvecinos=npb+1;
[n,~]=size(puntos);
if nvecinos > n
    nvecinos=n;
    [~,dist]=knnsearch(puntos,puntos,'NSMethod','kdtree','distance','euclidean','k',nvecinos);
    data=dist(:,nvecinos); %tomamos todos las distancias del 4� vecino
else
    [~,dist]=knnsearch(puntos,puntos,'NSMethod','kdtree','distance','euclidean','k',nvecinos);
    if n<5
        data=dist(:,n); %tomamos todos las distancias del �ltimo vecino
    else
        data=dist(:,5); %tomamos todos las distancias del 4� vecino
    end
end
data=unique(data,'sorted'); %ordenamos la las distancias
eps=mean(data)+ksigmaseps*std(data);

for ii=1:nf
    jointset=find(familia==ii); %�ndices de los puntos que pertenecen a la fam ii
    % puntos(I,:); % coordenadas de los puntos de la familia ii
    % el n�mero de cercanos lo fijamos en 4 por publicaci�n del DBSCAN
    puntos_familia_cluster(jointset,5)=f_dbscan(puntos(jointset,:),eps, ppcluster);
    [nc,~]=max(puntos_familia_cluster(jointset,5)); % nc n�mero de cl�sters para la familia ii
    % con las familias y los cluster, calculamos la ecuaci�n del plano de
    % cada cluster, notaci�n Ax+By+Cz+D=0, y o metemos en
    % familia_cluster_plano
    h=waitbar(0,['Calculating JS # ',num2str(ii),' cluster equations. Please wait']);
    for jj=1:nc
        jointset=find(puntos_familia_cluster(:,4)==ii & puntos_familia_cluster(:,5)==jj);
        M=puntos_familia_cluster(jointset,1:3); % matriz que tiene los puntos le la familia ii y cluster jj
        if vnfamilia==0
            % calculamos el vector normal ajust�ndolo al cl�ster
            [pc, ~, ~ ] = princomp (M,'econ');
            vn=cross(pc(:,1),pc(:,2));% vector normal
            vn=vn/norm(vn); %vector normal normalizado, |vn|=1
            A=vn(1);
            B=vn(2);
            C=vn(3);
        else
            % utilizamos el vn calculado para toda la familia
            omega=planos_pples(ii,1)/180*pi;
            beta=planos_pples(ii,2)/180*pi;
            [ A,B,C ] = f_vbuz2vnor( omega,beta );
        end
        sx=sum(puntos_familia_cluster(jointset,1));
        sy=sum(puntos_familia_cluster(jointset,2));
        sz=sum(puntos_familia_cluster(jointset,3));
        [np,~]=size(jointset);
        if C~=0
            a1=-A/C;
            a2=-B/C;
            a0=1/np*(sz-a1*sx-a2*sy);
            D=-a0*C;
        else
            if B~=0
                a1=-A/B;
                a0=1/np*(sy-a1*sx);
                D=-a0*B;
            else
                if A~=0
                    a1=-B/A;
                    a0=1/np*(sx-a1*sy);
                    D=-a0*A;
                end
            end
        end
        v=[ii jj size(jointset,1) A B C D ];
        familia_cluster_plano=[familia_cluster_plano; v];
        waitbar(jj/nc,h);
    end 
    close(h);
end

% limpiamos las familias sin cl�sters
puntos_familia_cluster=puntos_familia_cluster(puntos_familia_cluster(:,5)>0,:);

%% unificaci�n de clusters seg�n su desviaci�n t�pica
% calculamos la sigma de cada cluster para cada familia
% INUTILIZO ESTA PARTE PORQUE LA SACO A OTRO BOT�N
% if or(ksigmas==0,vnfamilia==0) % ksigmas==0 && vnfamilia==1
%     % no hacemos nada porque o bien ksigmas es nulo y por tanto no se
%     % unifican o bien los planos de los clusters no son paralelos, y por
%     % tanto no tiene sentido hacer este ajuste
% else
%     jointset = unique(puntos_familia_cluster(:,4)); % vector con los �ndices de las familias
%     [njs,~]=size(jointset); % njs es el n�mero de familias que hay
%     % Calculamos las desviaciones t�picas de las distancias punto-plano
%     % para cada cluster
%     % calculo el n�mero de clusters que hay, y por tanto as� habr� de
%     % desviaciones t�picas
%     ncl = sum(familia_cluster_plano(:,2));
%     sigmas = zeros(ncl,3); %matriz dd se guardan las sigmas fam cluster
%     % h=waitbar(0,['Calculating the deviations of the point - best-fit-plane. Please wait']);
%     contadorsigmas = 1;
%     for i=1:njs
%         Mjs=puntos_familia_cluster(puntos_familia_cluster(:,4)==jointset(i),:); % matriz con los puntos js y cluster de la familia i
%         cluster = unique(familia_cluster_plano(familia_cluster_plano(:,1)==i,2));
%         [ncs,~]=size(cluster); % ncs es el n�mero de clusters de esa familia
%         for j=1:ncs
%             vn=familia_cluster_plano(familia_cluster_plano(:,1)==jointset(i) & familia_cluster_plano(:,2)==cluster(j),4:7); % vector normal del cluster j
%             Aj=vn(1);
%             Bj=vn(2);
%             Cj=vn(3); 
%             Dj=vn(4);
%             ptos_j=Mjs(Mjs(:,4)==jointset(i) & Mjs(:,5)==cluster(j),1:3); % puntos del cluster j
%             [N,~]=size(ptos_j(:,1)); % numero de puntos del cluster j
%             sigma_j=sqrt(sum((Aj.*ptos_j(:,1)+Bj.*ptos_j(:,2)+Cj.*ptos_j(:,3)+Dj.*ones(size(ptos_j(:,1)))).^2,1)/(N-1)); % sigma de los puntos del cluster j
%             sigmas(contadorsigmas,1)=i;
%             sigmas(contadorsigmas,2)=j;
%             sigmas(contadorsigmas,3)=sigma_j;
%             contadorsigmas = contadorsigmas +1;
%             % waitbar(j/(ncs-1),h);
%         end
%         % close(h);
%     end
%     
%     for i=1:njs % recorremos todas las familias
%         h=waitbar(0,['Merging clusters of the joint set ',num2str(jointset(i)),'. Please wait']);
%         cluster = unique(familia_cluster_plano(familia_cluster_plano(:,1)==i,2));
%         [ncs,~]=size(cluster); %ncs es el n�mero de clusters de esa familia
%         sigmas_cluster = sigmas(sigmas(:,1)==i,3); % todos los sigmas de esa familia
%         D_cluster = familia_cluster_plano(familia_cluster_plano(:,1)==jointset(i),7); % todos los Ds de esa familia
%         % test = zeros(size(sigmas_cluster));
%         for j=1:ncs-1 % recorremos todos los clusters menos el �ltimo, porque ese no se va a buscar consigo mismo
%             sigma_j=sigmas(sigmas(:,1)==i & sigmas(:,2)==j,3);
%             % guardo la sigma en ese cluster
%             familia_cluster_plano(familia_cluster_plano(:,1)==i & familia_cluster_plano(:,2)==j,8)=sigma_j;
%             Dj=familia_cluster_plano(familia_cluster_plano(:,1)==jointset(i) & familia_cluster_plano(:,2)==cluster(j),7);
%             test = abs(D_cluster(j+1:ncs,1) - Dj) ./ (sigma_j + sigmas_cluster(j+1:ncs,1));
%             b = cluster(ksigmas>=test)+j; % ids de los clusters que han pasado el test para esa familia
%             % antes de asignar el valor de D a los clusters que toquen,
%             % debo de comprobar si hay alg�n cluster al que asignar eso
%             if isempty(b)
%                 % como est� vac�a, no asigno nada
%             else
%                 % hay alg�n cl�ster al que asignar
%                 % hay que recorrer uno a uno los clusters, luego tengo que
%                 % meter un for
%                 for mm=1:length(b)
%                     familia_cluster_plano(familia_cluster_plano(:,1)==i & familia_cluster_plano(:,2)==b(mm),7)=Dj;
%                     % Le a�ado tambi�n el valor del sigma que se ha usado
%                     % para el c�lculo
%                     familia_cluster_plano(familia_cluster_plano(:,1)==i & familia_cluster_plano(:,2)==b(mm),8)=sigma_j;
%                 end
%             end
%             waitbar(j/(ncs-1),h);
%         end
%         close(h);
%     end
% end

end


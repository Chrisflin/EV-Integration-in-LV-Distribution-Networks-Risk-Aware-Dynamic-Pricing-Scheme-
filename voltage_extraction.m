
function [Voltage]=voltage_extraction(BusNames,NodeNames,k)

lb=length(BusNames);
ln=length(NodeNames);

for x=1:lb
    node1=[BusNames{x},'.1'];
    node2=[BusNames{x},'.2'];
    node3=[BusNames{x},'.3'];
      
    for j=1:ln
        if strcmp(node1,NodeNames{j})
            VAn(x)=k((2*j)-1)+1i*k(2*j);
        end
    end
    for j=1:ln
        if strcmp(node2,NodeNames{j})
            VBn(x)=k((2*j)-1)+1i*k(2*j);
        end
    end
    for j=1:ln
        if strcmp(node3,NodeNames{j})
            VCn(x)=k((2*j)-1)+1i*k(2*j);
        end
    end
end

Voltage.VAN_vec=VAn;
Voltage.VBN_vec=VBn;
Voltage.VCN_vec=VCn;
Voltage.VAN_mag=abs(VAn);
Voltage.VBN_mag=abs(VBn);
Voltage.VCN_mag=abs(VCn);
Voltage.VAN_ang=rad2deg(angle(VAn));
Voltage.VBN_ang=rad2deg(angle(VBn));
Voltage.VCN_ang=rad2deg(angle(VCn));
end

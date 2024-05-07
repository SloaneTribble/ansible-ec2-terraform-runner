[ec2hosts]
%{ for ip in ips ~}
${ip}
%{ endfor ~}

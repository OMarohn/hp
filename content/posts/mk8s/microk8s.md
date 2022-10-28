---
title: "Aufsetzen von mircoK8s"
date: 2022-10-01
description: "Aufsetzen von microK8s unter ubuntu"
summary: "Aufsetzen eines microK8s-Servers unter ubuntu"
tags: ["k8s", "mircroK8s", "ubuntu","cert-manager", "istio"]
type: 'how2'
---

# microk8s einrichten

## Installation

Entweder direkt bei der Installtion des Ubuntu Servers mit auswählen oder aber mit `sudo snap install microk8s --classic` installieren. Mit `microk8s status` kann man sich eine Liste der möglichen zusäzlichen Service ausgeben lassen.

## Ubuntu Firewall

Die Firewall `ufw` kann bei Verbindungsproblemen einfach zum testen disabled werden.

`sudo ufw disable`

Natürlich sollte die FW später wieder aktiviert werden. Zur Kommunikation mit dem K8s-API-Server wird der Port **16443** benötigt, je nachdem wie dann weiter von außen auf den Kubernetes zugegriffen werden soll - in meinem Falle über den ISTIO Ingress-Controller - müssen dann die entsprechenden Ports freig egeben werden. Da in microK8s kein LB verfügbar ist wird hier der NodePort für den Ingeres-Controller verwendet. Es existiert auch ein snap für den **MetalLB**, den ich hier aber nicht verwende. 

{{< alert >}}
**Hinweis** Weitere infos zu [Meltallb](https://metallb.universe.tf/)
{{< /alert >}}

```bash
export INGRESS_PORT=$(k -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(k -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export TCP_INGRESS_PORT=$(k -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].nodePort}')
```

Also `sudo ufw allow $SECURE_INGRESS_PORT` sicherer wird es noch wenn bspw. der Zugriff nur vom Router erlaubt wird. In obigen Fall wird der Zugriff von allen Endpunkten erlaubt. Ganz gut erklärt wird das bspw. bei [Heise](https://www.heise.de/tipps-tricks/Ubuntu-Firewall-einrichten-4633959.html) oder im Detail im [Ubuntu WIKI](https://wiki.ubuntuusers.de/ufw/)

## KUBECONFIG ermitteln

Die KUBECONFIG lässt sich einfach mit `microk8s config` ermitteln und in einen File pipen. Die kann dann auch von anderen Rechnern aus zur Kommunikation mit dem K8s verwendet werden.

## ISTIO installieren

Es existiert ein Plugin für microK8s, das aber relativ alt ist, deshalb installiere ich die aktuelle Version selber. [ISTIO installtion](https://istio.io/latest/docs/setup/getting-started/). Damit die Installation aber funktionieren kann, muss anscheinend doch zuerst das **Plugin aktivert werden**!!! (Wahrscheinlich, weil das Plugin auch was mit Calicio macht, ansonsten wird nämlich kein ingress/egress Pod hochgezogen. Auch die FW Regeln müssten dann von Hand erstellt werden, was mir nicht so einfach gelingen wollte)

{{< alert >}}
**Hinweis** Zuerst das snap von Istio aktivieren, damit auch die FW-Regeln erzeugt werden. Dann einfach neuest Version drüber installieren.
{{< /alert >}}

```bash
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY
```

## Cert-Manager

Der Cert-Manager, erlaubt es lets-Encrypt SSL-Zertifikate zu einzusetzen. Auch hier gibt es ein Plugin `microk8s enable cert-manager`
Dann nicht vergessen den Issuer zu definieren / deployen

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: istio-system
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: omarohn@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory # prod
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: le-issuer-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: istio
```

## MFA

Hab ich noch nen Problem mit

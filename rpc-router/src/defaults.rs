//! Default constants
use std::net::SocketAddr;

pub(crate) const ZEBRA_URL: &str = "http://127.0.0.1:20251";

pub(crate) const ZALLET_URL: &str = "http://127.0.0.1:25251";

pub(crate) const ZAINO_URL: &str = "http://zaino:8237";

pub(crate) const RPC_USER: &str = "zebra";

pub(crate) const RPC_PASSWORD: &str = "zebra";

pub(crate) const CORS_ORIGIN: &str = "https://playground.open-rpc.org";

pub(crate) const LISTEN_PORT: u16 = 8080;

pub(crate) const PLAYGROUND_URL: &str = "https://playground.open-rpc.org/?uiSchema[appBar][ui:title]=Zcash&uiSchema[appBar][ui:logoUrl]=https://z.cash/wp-content/uploads/2023/03/zcash-logo.gif&schemaUrl={{addr}}&uiSchema[appBar][ui:splitView]=false&uiSchema[appBar][ui:edit]=false&uiSchema[appBar][ui:input]=false&uiSchema[appBar][ui:examplesDropdown]=false&uiSchema[appBar][ui:transports]=false";

pub(crate) fn playground_url(addr: SocketAddr) -> String {
    PLAYGROUND_URL.replace("{{addr}}", &addr.to_string())
}
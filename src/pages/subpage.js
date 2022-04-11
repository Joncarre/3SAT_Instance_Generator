import React, { useEffect } from "react";

const FooterSubpage = ({ Comp }) => {
    useEffect(() => {
        // scroll to the top of the page when rendered
        window.scrollTo(0, 0);
    }, [])
    return <Comp />;
}
export default FooterSubpage;